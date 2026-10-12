package com.example.lnote

import android.content.Context
import android.content.SharedPreferences
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

/**
 * Restriction state for a controlled application.
 */
enum class RestrictionState {
    UNCONTROLLED,
    ALLOWED,
    RESTRICTED,
    NEEDS_REASON,
    TEMP_ACCESS
}

/**
 * Explicit diagnostic health state for usage monitoring.
 */
enum class MonitoringHealthState {
    ACTIVE,
    DEGRADED_PERMISSION_MISSING,
    DEGRADED_SERVICE_UNAVAILABLE,
    DEGRADED_DATA_STALE,
    RECOVERED
}

/**
 * Result of a temporary access request.
 */
data class AccessRequestResult(
    val granted: Boolean,
    val packageName: String,
    val expirationTimestamp: Long,
    val reason: String
)

/**
 * Dedicated restriction and policy engine interface.
 */
interface AppRestrictionEngine {
    fun getRestrictionState(packageName: String): RestrictionState
    fun getRemainingDailyUsage(packageName: String): Long
    fun requestTemporaryAccess(
        packageName: String,
        reason: String,
        durationMillis: Long
    ): AccessRequestResult
    fun expireTemporaryAccess(packageName: String)
    fun isControlled(packageName: String): Boolean
    fun isStrict(packageName: String): Boolean
    fun evaluateForegroundAndEnforce(knownForegroundPkg: String? = null): RestrictionState
    fun getMonitoringHealth(): MonitoringHealthState
    fun getHealthDiagnosticInfo(): Map<String, Any>
}

/**
 * Implementation of AppRestrictionEngine using UsageStatsManager usage calculations,
 * atomic SharedPreferences persistence, and independent session management.
 */
class AppRestrictionEngineImpl(
    private val context: Context,
    private val appUsageMonitor: AppUsageMonitor
) : AppRestrictionEngine {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)

    override fun evaluateForegroundAndEnforce(knownForegroundPkg: String?): RestrictionState {
        val fgPkg = knownForegroundPkg ?: appUsageMonitor.getForegroundPackageNow() ?: return RestrictionState.UNCONTROLLED
        if (fgPkg == context.packageName) return RestrictionState.UNCONTROLLED

        val state = getRestrictionState(fgPkg)
        val launcher = BlockerLauncher(context)

        when (state) {
            RestrictionState.RESTRICTED -> {
                AppUsageDiagnosticLogger.i("Foreground app [$fgPkg] is RESTRICTED (Normal Mode limit). Launching blocker.")
                launcher.launchBlocker(fgPkg, "normal")
            }
            RestrictionState.NEEDS_REASON -> {
                AppUsageDiagnosticLogger.i("Foreground app [$fgPkg] NEEDS_REASON (Strict Mode). Launching blocker.")
                launcher.launchBlocker(fgPkg, "strict")
            }
            else -> {
                // ALLOWED, TEMP_ACCESS, or UNCONTROLLED
            }
        }

        return state
    }

    override fun isControlled(packageName: String): Boolean {
        val controlled = getSafeStringSet("controlled_packages")
        return controlled.contains(packageName)
    }

    override fun isStrict(packageName: String): Boolean {
        val strict = getSafeStringSet("strict_packages")
        return strict.contains(packageName)
    }

    override fun getMonitoringHealth(): MonitoringHealthState {
        if (!appUsageMonitor.hasUsageAccess()) {
            AppUsageDiagnosticLogger.w("Monitoring health check: DEGRADED_PERMISSION_MISSING")
            return MonitoringHealthState.DEGRADED_PERMISSION_MISSING
        }
        val isServiceAvailable = (context.getSystemService(Context.USAGE_STATS_SERVICE) != null)
        if (!isServiceAvailable) {
            AppUsageDiagnosticLogger.w("Monitoring health check: DEGRADED_SERVICE_UNAVAILABLE")
            return MonitoringHealthState.DEGRADED_SERVICE_UNAVAILABLE
        }
        return MonitoringHealthState.ACTIVE
    }

    override fun getHealthDiagnosticInfo(): Map<String, Any> {
        val health = getMonitoringHealth()
        val hasUsage = appUsageMonitor.hasUsageAccess()
        val controlled = getSafeStringSet("controlled_packages")
        val strict = getSafeStringSet("strict_packages")
        val now = System.currentTimeMillis()
        val fg = appUsageMonitor.getForegroundPackageNow() ?: "none"

        return mapOf(
            "healthState" to health.name,
            "hasUsageAccess" to hasUsage,
            "controlledCount" to controlled.size,
            "strictCount" to strict.size,
            "foregroundPackage" to fg,
            "timestamp" to now
        )
    }

    override fun getRestrictionState(packageName: String): RestrictionState {
        if (!isControlled(packageName)) {
            return RestrictionState.UNCONTROLLED
        }

        // 1. Check if temporary access session is currently active
        val expireTimestamp = prefs.getLong("temp_access_$packageName", 0L)
        val now = System.currentTimeMillis()

        if (expireTimestamp > 0L) {
            if (now < expireTimestamp) {
                return RestrictionState.TEMP_ACCESS
            } else {
                expireTemporaryAccess(packageName)
            }
        }

        // 2. Strict Mode: Requires conscious reason on every new access attempt
        if (isStrict(packageName)) {
            return RestrictionState.NEEDS_REASON
        }

        // 3. Normal Mode: Check daily limit vs aggregated usage
        val dailyLimitMinutes = prefs.getInt("daily_limit_$packageName", 30)
        val dailyLimitMs = dailyLimitMinutes * 60 * 1000L
        val usedMs = appUsageMonitor.getDailyUsage(packageName)

        return if (usedMs >= dailyLimitMs) {
            RestrictionState.RESTRICTED
        } else {
            RestrictionState.ALLOWED
        }
    }

    override fun getRemainingDailyUsage(packageName: String): Long {
        if (!isControlled(packageName)) return Long.MAX_VALUE
        val dailyLimitMinutes = prefs.getInt("daily_limit_$packageName", 30)
        val dailyLimitMs = dailyLimitMinutes * 60 * 1000L
        val usedMs = appUsageMonitor.getDailyUsage(packageName)
        return (dailyLimitMs - usedMs).coerceAtLeast(0L)
    }

    override fun requestTemporaryAccess(
        packageName: String,
        reason: String,
        durationMillis: Long
    ): AccessRequestResult {
        if (durationMillis <= 0L || reason.trim().isEmpty()) {
            return AccessRequestResult(
                granted = false,
                packageName = packageName,
                expirationTimestamp = 0L,
                reason = "Invalid duration or empty reason"
            )
        }

        val now = System.currentTimeMillis()
        val expiresAt = now + durationMillis
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

        prefs.edit()
            .putLong("temp_remaining_ms_$packageName", durationMillis)
            .putString("temp_remaining_date_$packageName", todayStr)
            .putLong("temp_access_$packageName", expiresAt)
            .commit()

        val appName = try {
            val pm = context.packageManager
            val info = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            packageName.substringAfterLast('.')
        }

        val mode = if (isStrict(packageName)) "strict" else "normal"
        saveInterventionRecord(packageName, appName, reason, (durationMillis / 60000).toInt(), mode)

        AppUsageDiagnosticLogger.i("Temporary access granted for [$packageName] until $expiresAt (Reason: '$reason')")

        return AccessRequestResult(
            granted = true,
            packageName = packageName,
            expirationTimestamp = expiresAt,
            reason = reason
        )
    }

    override fun expireTemporaryAccess(packageName: String) {
        prefs.edit()
            .remove("temp_remaining_ms_$packageName")
            .remove("temp_remaining_date_$packageName")
            .remove("temp_access_$packageName")
            .commit()
        AppUsageDiagnosticLogger.i("Temporary access expired & revoked for [$packageName]")
    }

    private fun getTemporaryRemainingMs(packageName: String): Long {
        val expireTimestamp = prefs.getLong("temp_access_$packageName", 0L)
        val now = System.currentTimeMillis()
        if (expireTimestamp > 0L) {
            val remaining = expireTimestamp - now
            if (remaining > 0L) {
                return remaining
            } else {
                expireTemporaryAccess(packageName)
                return 0L
            }
        }
        return 0L
    }

    private fun getSafeStringSet(key: String): Set<String> {
        return try {
            prefs.getStringSet(key, null) ?: emptySet()
        } catch (e: Exception) {
            try {
                val str = prefs.getString(key, null) ?: return emptySet()
                if (str.startsWith("[")) {
                    val array = JSONArray(str)
                    val set = mutableSetOf<String>()
                    for (i in 0 until array.length()) {
                        set.add(array.getString(i))
                    }
                    set
                } else {
                    str.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toSet()
                }
            } catch (e2: Exception) {
                emptySet()
            }
        }
    }

    private fun saveInterventionRecord(
        packageName: String,
        appName: String,
        reason: String,
        durationMins: Int,
        mode: String
    ) {
        try {
            val now = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())
            val file = File(context.filesDir, "usage_reasons.json")
            val reasonsArray = if (file.exists()) {
                val content = file.readText()
                if (content.isNotEmpty()) JSONArray(content) else JSONArray()
            } else {
                JSONArray()
            }

            val parsedCategory = if (reason.startsWith("[") && reason.contains("]")) {
                reason.substring(1, reason.indexOf(']')).lowercase()
            } else {
                "other"
            }
            val cleanReason = if (reason.startsWith("[") && reason.contains("]")) {
                reason.substring(reason.indexOf(']') + 1).trim()
            } else {
                reason
            }

            val reasonObj = JSONObject().apply {
                put("id", "reas_${System.currentTimeMillis()}")
                put("sessionId", "sess_${System.currentTimeMillis()}")
                put("packageId", packageName)
                put("appName", appName)
                put("mode", mode)
                put("timestamp", now)
                put("category", parsedCategory)
                put("customReason", cleanReason)
                put("requestedMinutes", durationMins)
                put("approvedMinutes", durationMins)
                put("wasAllowed", true)
            }
            reasonsArray.put(reasonObj)
            file.writeText(reasonsArray.toString())
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Error saving intervention record to usage_reasons.json", e)
        }
    }
}
