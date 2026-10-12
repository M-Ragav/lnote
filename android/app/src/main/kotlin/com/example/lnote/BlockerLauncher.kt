package com.example.lnote

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.concurrent.ConcurrentHashMap

import android.provider.Settings

/**
 * Blocker Launcher.
 *
 * Coordinates starting the full-screen conscious blocker interface.
 * Implements strict deduplication and state verification to avoid
 * duplicate windows, flickering, or interruption while the user is typing.
 * Includes notification fallback when background activity launch is restricted by Android 10+.
 */
class BlockerLauncher(private val context: Context) {

    companion object {
        private val lastLaunchTimes = ConcurrentHashMap<String, Long>()
        private const val debounceWindowMs = 1200L
        private const val NOTIF_CHANNEL_ID = "lnote_blocker_prompts"
    }

    /**
     * Launch the conscious blocker activity for the restricted app.
     */
    fun launchBlocker(packageName: String, mode: String = "normal"): Boolean {
        // 1. Verify if the Blocker Activity or Overlay is already active in the foreground
        if (AppUsageBlockerOverlayManager.isShowingFor(packageName) || AppUsageBlockerActivity.isShowingFor(packageName)) {
            AppUsageDiagnosticLogger.logBlockerSuppressed(
                packageName,
                "Blocker is already actively displaying for this package"
            )
            return false
        }

        // 2. Debounce repeated triggers within short window
        val now = System.currentTimeMillis()
        val lastLaunch = lastLaunchTimes[packageName] ?: 0L
        if (now - lastLaunch < debounceWindowMs) {
            AppUsageDiagnosticLogger.logBlockerSuppressed(
                packageName,
                "Debounce active (${now - lastLaunch}ms < ${debounceWindowMs}ms)"
            )
            return false
        }

        lastLaunchTimes[packageName] = now
        AppUsageDiagnosticLogger.logBlockerLaunched(packageName, mode)

        val hasOverlay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }

        if (hasOverlay) {
            // WindowManager overlay: immune to OEM Background Activity Launch (BAL) blocking
            AppUsageBlockerOverlayManager.show(context, packageName, mode)
        } else {
            val intent = Intent(context, AppUsageBlockerActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
                putExtra(AppUsageBlockerActivity.EXTRA_PACKAGE_NAME, packageName)
                putExtra(AppUsageBlockerActivity.EXTRA_MODE, mode)
            }

            try {
                context.startActivity(intent)
            } catch (e: Exception) {
                AppUsageDiagnosticLogger.e("Direct startActivity failed for $packageName", e)
            }

            // If overlay permission is not granted, display the high-priority full-screen intent notification
            showBlockerNotificationFallback(packageName, mode)
        }

        return true
    }

    /**
     * Supported notification fallback when background activity start is restricted by Android 10+.
     */
    fun showBlockerNotificationFallback(packageName: String, mode: String) {
        try {
            val appName = try {
                val appInfo = context.packageManager.getApplicationInfo(packageName, 0)
                context.packageManager.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                packageName.substringAfterLast('.')
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    "LNote Conscious Usage Prompts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Prompts to reflect before opening restricted applications"
                }
                notificationManager.createNotificationChannel(channel)
            }

            val blockerIntent = Intent(context, AppUsageBlockerActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(AppUsageBlockerActivity.EXTRA_PACKAGE_NAME, packageName)
                putExtra(AppUsageBlockerActivity.EXTRA_APP_NAME, appName)
                putExtra(AppUsageBlockerActivity.EXTRA_MODE, mode)
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                (packageName.hashCode() % 100000),
                blockerIntent,
                pendingIntentFlags
            )

            val notification = NotificationCompat.Builder(context, NOTIF_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Conscious Pause: $appName")
                .setContentText("Tap to reflect and set your intention before continuing.")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setFullScreenIntent(pendingIntent, true)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .build()

            notificationManager.notify((packageName.hashCode() % 100000) + 1, notification)
            AppUsageDiagnosticLogger.i("Posted conscious blocker notification fallback for [$packageName]")
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Failed to post notification fallback for $packageName", e)
        }
    }
}
