package com.example.lnote

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.Calendar

class AppUsageAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_SESSION_EXPIRED = "com.example.lnote.ACTION_SESSION_EXPIRED"
        const val ACTION_MIDNIGHT_ROLLOVER = "com.example.lnote.ACTION_MIDNIGHT_ROLLOVER"
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        const val EXTRA_APP_NAME = "extra_app_name"
        private const val NOTIF_CHANNEL_ID = "lnote_app_usage_alerts"

        fun scheduleSessionExpireAlarm(context: Context, packageName: String, appName: String, triggerAtMillis: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, AppUsageAlarmReceiver::class.java).apply {
                action = ACTION_SESSION_EXPIRED
                putExtra(EXTRA_PACKAGE_NAME, packageName)
                putExtra(EXTRA_APP_NAME, appName)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, (packageName.hashCode() % 100000), intent, flags)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
            AppUsageDiagnosticLogger.i("Scheduled session expiration alarm for [$packageName] at $triggerAtMillis")
        }

        fun cancelSessionExpireAlarm(context: Context, packageName: String) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, AppUsageAlarmReceiver::class.java).apply {
                action = ACTION_SESSION_EXPIRED
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, (packageName.hashCode() % 100000), intent, flags)
            alarmManager.cancel(pendingIntent)
        }

        fun scheduleMidnightRollover(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, AppUsageAlarmReceiver::class.java).apply {
                action = ACTION_MIDNIGHT_ROLLOVER
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, 99991, intent, flags)

            val calendar = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 2)
                set(Calendar.MILLISECOND, 0)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
            }
            AppUsageDiagnosticLogger.i("Scheduled next midnight rollover check for ${calendar.timeInMillis}")
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            ACTION_SESSION_EXPIRED -> {
                val packageName = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: return
                val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: "Controlled App"

                // 1. Clear temporary access from SharedPreferences
                val prefs = context.getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
                prefs.edit()
                    .remove("temp_remaining_ms_$packageName")
                    .remove("temp_remaining_date_$packageName")
                    .remove("temp_access_$packageName")
                    .commit()
                AppUsageDiagnosticLogger.logSessionUpdate(packageName, "ALARM_SESSION_EXPIRED", 0L)

                // 2. Check if user is actively using the restricted app; if so, trigger blocker immediately
                try {
                    val appUsageMonitor: AppUsageMonitor = AppUsageMonitorImpl(context)
                    val fgPkg = appUsageMonitor.getForegroundPackageNow()
                    if (fgPkg == packageName) {
                        val strictSet = prefs.getStringSet("strict_packages", emptySet()) ?: emptySet()
                        val mode = if (strictSet.contains(packageName)) "strict" else "normal"
                        AppUsageDiagnosticLogger.i("Session duration expired for [$packageName] while in foreground: launching conscious blocker immediately")
                        val launcher = BlockerLauncher(context)
                        launcher.launchBlocker(packageName, mode)
                    }
                } catch (e: Exception) {
                    AppUsageDiagnosticLogger.e("Failed to trigger conscious blocker on session expiration", e)
                }

                // 3. Notify user that temporary access has expired
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val channel = NotificationChannel(
                        NOTIF_CHANNEL_ID,
                        "LNote App Usage Limits",
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply {
                        description = "Alerts when conscious usage sessions expire"
                    }
                    notificationManager.createNotificationChannel(channel)
                }

                val notification = NotificationCompat.Builder(context, NOTIF_CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("Session Expired: $appName")
                    .setContentText("Your scheduled time for $appName has concluded. Staying conscious of screen time!")
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setAutoCancel(true)
                    .build()

                notificationManager.notify((packageName.hashCode() % 100000), notification)
            }
            ACTION_MIDNIGHT_ROLLOVER -> {
                AppUsageDiagnosticLogger.i("Midnight rollover reached. Purging stale daily temporary allowances and re-scheduling next day rollover.")
                val prefs = context.getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
                val editor = prefs.edit()
                val todayStr = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
                for (key in prefs.all.keys) {
                    if (key.startsWith("temp_remaining_date_")) {
                        val savedDate = prefs.getString(key, null)
                        if (savedDate != null && savedDate != todayStr) {
                            val pkg = key.removePrefix("temp_remaining_date_")
                            editor.remove(key)
                            editor.remove("temp_remaining_ms_$pkg")
                            editor.remove("temp_access_$pkg")
                            AppUsageDiagnosticLogger.i("Midnight rollover: Cleared stale session for [$pkg] from date $savedDate")
                        }
                    }
                }
                editor.apply()
                scheduleMidnightRollover(context)
            }
        }
    }
}
