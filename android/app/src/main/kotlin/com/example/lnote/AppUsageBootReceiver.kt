package com.example.lnote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Boot receiver to reconcile active sessions and re-schedule midnight rollover alarm after device restart.
 */
class AppUsageBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            AppUsageDiagnosticLogger.i("Device reboot detected (ACTION_BOOT_COMPLETED). Reconciling app usage sessions.")

            // 1. Re-schedule daily midnight rollover alarm
            AppUsageAlarmReceiver.scheduleMidnightRollover(context)

            // 2. Reconcile temporary access sessions
            val prefs = context.getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val allKeys = prefs.all.keys

            val editor = prefs.edit()
            for (key in allKeys) {
                if (key.startsWith("temp_access_")) {
                    val pkg = key.removePrefix("temp_access_")
                    val expiresAt = prefs.getLong(key, 0L)
                    if (expiresAt <= now) {
                        // Expired during device power off
                        editor.remove("temp_remaining_ms_$pkg")
                        editor.remove("temp_remaining_date_$pkg")
                        editor.remove(key)
                        AppUsageDiagnosticLogger.i("Reboot reconciliation: Expired session cleaned for [$pkg]")
                    } else {
                        // Session still active; re-schedule alarm for remaining duration
                        val appName = try {
                            val info = context.packageManager.getApplicationInfo(pkg, 0)
                            context.packageManager.getApplicationLabel(info).toString()
                        } catch (e: Exception) {
                            pkg.substringAfterLast('.')
                        }
                        AppUsageAlarmReceiver.scheduleSessionExpireAlarm(context, pkg, appName, expiresAt)
                        AppUsageDiagnosticLogger.i("Reboot reconciliation: Restored active session alarm for [$pkg] until $expiresAt")
                    }
                }
            }
            editor.apply()
            
            // 3. Resume foreground app usage monitoring service if controlled packages exist
            AppUsageMonitoringService.updateServiceState(context)
        }
    }
}
