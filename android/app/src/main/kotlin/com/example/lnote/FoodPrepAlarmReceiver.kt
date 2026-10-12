package com.example.lnote

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class FoodPrepAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action

        if (action == ACTION_TEMP_SKIP) {
            FoodPrepOverlayService.handleTempSkip(context)
            dismissNotification(context)
            return
        }

        if (action == ACTION_SKIP_TODAY) {
            FoodPrepOverlayService.handleSkipToday(context)
            dismissNotification(context)
            return
        }

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean("flutter.food_prep_enabled", true)
        if (!isEnabled) return

        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val lastSkipped = prefs.getString("flutter.food_prep_last_skipped_date", null)
        if (lastSkipped == todayStr) {
            // Already skipped for today
            return
        }

        // 1. If overlay permission is granted, start floating window over other apps
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)) {
            val serviceIntent = Intent(context, FoodPrepOverlayService::class.java).apply {
                this.action = FoodPrepOverlayService.ACTION_SHOW
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 2. Also show heads-up high priority notification with actions
        showNotification(context)

        // 3. Schedule next day's alarm
        scheduleNextDailyAlarm(context)
    }

    companion object {
        const val ACTION_ALARM_TRIGGER = "com.example.lnote.ACTION_FOOD_PREP_ALARM"
        const val ACTION_TEMP_SKIP = "com.example.lnote.ACTION_FOOD_PREP_TEMP_SKIP"
        const val ACTION_SKIP_TODAY = "com.example.lnote.ACTION_FOOD_PREP_SKIP_TODAY"
        const val NOTIFICATION_ID = 9001
        const val CHANNEL_ID = "lnote_food_prep"

        fun buildNotification(context: Context): Notification {
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()

                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Food Preparation Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Daily alerts to prepare food for tomorrow"
                    enableVibration(true)
                    enableLights(true)
                    setSound(soundUri, audioAttributes)
                }
                notificationManager.createNotificationChannel(channel)
            }

            // Tap opens app
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                910,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Action: Temp Skip (10 min)
            val tempSkipIntent = Intent(context, FoodPrepAlarmReceiver::class.java).apply {
                action = ACTION_TEMP_SKIP
            }
            val tempSkipPending = PendingIntent.getBroadcast(
                context,
                911,
                tempSkipIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Action: Skip Today
            val skipTodayIntent = Intent(context, FoodPrepAlarmReceiver::class.java).apply {
                action = ACTION_SKIP_TODAY
            }
            val skipTodayPending = PendingIntent.getBroadcast(
                context,
                912,
                skipTodayIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
            val tomorrowDayName = SimpleDateFormat("EEEE", Locale.US).format(tomorrowCal.time)

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Food Preparation • Tomorrow ($tomorrowDayName)")
                .setContentText("Check off foods required for tomorrow so you never miss a meal!")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setAutoCancel(true)
                .setSound(soundUri)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setContentIntent(openAppPendingIntent)
                .addAction(R.mipmap.ic_launcher, "Temp Skip (10m)", tempSkipPending)
                .addAction(R.mipmap.ic_launcher, "Skip Today", skipTodayPending)
                .build()
        }

        fun showNotification(context: Context) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val notification = buildNotification(context)
            notificationManager.notify(NOTIFICATION_ID, notification)
        }

        fun dismissNotification(context: Context) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(NOTIFICATION_ID)
        }

        fun scheduleNextDailyAlarm(context: Context) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val timeStr = prefs.getString("flutter.food_prep_time", "20:00") ?: "20:00"
            val parts = timeStr.split(":")
            val hour = parts.getOrNull(0)?.toIntOrNull() ?: 20
            val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0

            scheduleAlarm(context, hour, minute)
        }

        fun scheduleAlarm(context: Context, hour: Int, minute: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, FoodPrepAlarmReceiver::class.java).apply {
                action = ACTION_ALARM_TRIGGER
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                900,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val now = Calendar.getInstance()
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (before(now)) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target.timeInMillis, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, target.timeInMillis, pendingIntent)
            }
        }

        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, FoodPrepAlarmReceiver::class.java).apply {
                action = ACTION_ALARM_TRIGGER
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                900,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }
    }
}
