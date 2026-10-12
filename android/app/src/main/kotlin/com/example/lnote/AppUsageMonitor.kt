package com.example.lnote

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import java.util.Calendar

/**
 * Representation of a native UsageEvents event record.
 */
data class AppUsageEventRecord(
    val packageName: String,
    val eventType: Int,
    val timeStamp: Long,
    val className: String?
)

/**
 * Aggregated daily usage record for a monitored application.
 */
data class AppUsageRecord(
    val packageName: String,
    val appName: String,
    val totalTimeInForegroundMs: Long,
    val lastTimeUsed: Long
)

/**
 * Public interface for app usage monitoring via Android UsageStatsManager APIs.
 */
interface AppUsageMonitor {
    fun hasUsageAccess(): Boolean
    fun openUsageAccessSettings()
    fun getDailyUsage(packageName: String): Long
    fun getDailyUsageMap(): Map<String, Long>
    fun getUsageEvents(startTime: Long, endTime: Long): List<AppUsageEventRecord>
    fun getMonitoredAppUsage(): List<AppUsageRecord>
    fun getForegroundPackageNow(): String?
}

/**
 * Implementation of AppUsageMonitor using UsageStatsManager and UsageEvents.
 *
 * Provides real-time foreground detection, daily usage duration accumulation across sessions,
 * and handles reboot/rollover/restarts gracefully without relying on AccessibilityService.
 */
class AppUsageMonitorImpl(private val context: Context) : AppUsageMonitor {

    private val usageStatsManager: UsageStatsManager? by lazy {
        context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
    }

    override fun hasUsageAccess(): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Error checking Usage Access permission", e)
            false
        }
    }

    override fun openUsageAccessSettings() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Error opening Usage Access settings", e)
        }
    }

    override fun getDailyUsage(packageName: String): Long {
        if (!hasUsageAccess() || usageStatsManager == null) return 0L

        val map = getDailyUsageMap()
        return map[packageName] ?: 0L
    }

    override fun getDailyUsageMap(): Map<String, Long> {
        val resultMap = mutableMapOf<String, Long>()
        if (!hasUsageAccess() || usageStatsManager == null) return resultMap

        try {
            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val startOfDay = calendar.timeInMillis
            val now = System.currentTimeMillis()

            val statsList = usageStatsManager?.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                startOfDay,
                now
            ) ?: emptyList()

            for (stat in statsList) {
                if (stat.totalTimeInForeground > 0) {
                    resultMap[stat.packageName] =
                        (resultMap[stat.packageName] ?: 0L) + stat.totalTimeInForeground
                }
            }

            // Real-time compensation: If an app is actively in the foreground right now,
            // query recent events to add elapsed on-screen time since the last resume event
            val activeFgPkg = getForegroundPackageNow()
            if (activeFgPkg != null && activeFgPkg != context.packageName) {
                val recentEvents = getUsageEvents(now - 300_000L, now)
                val lastResume = recentEvents.lastOrNull {
                    it.packageName == activeFgPkg &&
                            (it.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                                    it.eventType == 1) // 1 = MOVE_TO_FOREGROUND
                }
                if (lastResume != null && lastResume.timeStamp < now) {
                    val activeSessionMs = (now - lastResume.timeStamp).coerceAtLeast(0L)
                    // If active session wasn't flushed to disk yet, add the active delta
                    val base = resultMap[activeFgPkg] ?: 0L
                    resultMap[activeFgPkg] = base + activeSessionMs
                }
            }
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Error querying daily usage stats map", e)
        }

        return resultMap
    }

    override fun getUsageEvents(startTime: Long, endTime: Long): List<AppUsageEventRecord> {
        val records = mutableListOf<AppUsageEventRecord>()
        if (!hasUsageAccess() || usageStatsManager == null) return records

        try {
            val events = usageStatsManager?.queryEvents(startTime, endTime) ?: return records
            val event = UsageEvents.Event()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                records.add(
                    AppUsageEventRecord(
                        packageName = event.packageName ?: "",
                        eventType = event.eventType,
                        timeStamp = event.timeStamp,
                        className = event.className
                    )
                )
            }
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Error querying UsageEvents", e)
        }

        return records
    }

    override fun getMonitoredAppUsage(): List<AppUsageRecord> {
        val list = mutableListOf<AppUsageRecord>()
        if (!hasUsageAccess()) return list

        try {
            val pm = context.packageManager
            val dailyUsage = getDailyUsageMap()

            val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val resolveInfos = pm.queryIntentActivities(mainIntent, 0)

            for (info in resolveInfos) {
                val pkg = info.activityInfo.packageName ?: continue
                if (pkg == context.packageName) continue

                val label = try {
                    info.loadLabel(pm).toString()
                } catch (e: Exception) {
                    pkg.substringAfterLast('.')
                }

                val usageMs = dailyUsage[pkg] ?: 0L
                list.add(
                    AppUsageRecord(
                        packageName = pkg,
                        appName = label,
                        totalTimeInForegroundMs = usageMs,
                        lastTimeUsed = System.currentTimeMillis()
                    )
                )
            }
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Error compiling monitored app usage list", e)
        }

        return list
    }

    /**
     * Determines the currently active foreground package name using recent UsageEvents.
     */
    override fun getForegroundPackageNow(): String? {
        if (!hasUsageAccess() || usageStatsManager == null) return null

        try {
            val now = System.currentTimeMillis()
            // Look across the last 30 minutes to capture currently active foreground app
            val startTime = now - (30 * 60 * 1000L)
            val events = usageStatsManager?.queryEvents(startTime, now + 1_000L) ?: return null
            val event = UsageEvents.Event()

            var lastResumedPkg: String? = null
            var lastResumedTime = 0L
            var lastPausedPkg: String? = null
            var lastPausedTime = 0L

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val pkg = event.packageName ?: continue
                if (pkg.isEmpty() || pkg == "android") continue

                when (event.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED, 1 -> {
                        if (event.timeStamp >= lastResumedTime) {
                            lastResumedTime = event.timeStamp
                            lastResumedPkg = pkg
                        }
                    }
                    UsageEvents.Event.ACTIVITY_PAUSED, 2, 23 -> {
                        if (event.timeStamp >= lastPausedTime) {
                            lastPausedTime = event.timeStamp
                            lastPausedPkg = pkg
                        }
                    }
                }
            }

            // If the last resumed package has not been superseded by a pause event, it is currently in foreground
            if (lastResumedPkg != null && lastResumedTime >= lastPausedTime) {
                return lastResumedPkg
            }

            // If last resumed is different from last paused, it remains the primary visible window
            if (lastResumedPkg != null && lastResumedPkg != lastPausedPkg) {
                return lastResumedPkg
            }

            // Fallback: check queryUsageStats for package with latest lastTimeUsed
            val statsList = usageStatsManager?.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                startTime,
                now
            ) ?: emptyList()

            var latestPackage: String? = null
            var latestTime = 0L
            for (stat in statsList) {
                if (stat.packageName != "android" &&
                    stat.packageName != context.packageName &&
                    stat.lastTimeUsed > latestTime
                ) {
                    latestTime = stat.lastTimeUsed
                    latestPackage = stat.packageName
                }
            }

            return latestPackage
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Error determining foreground package", e)
            return null
        }
    }
}
