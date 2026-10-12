package com.example.lnote

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

/**
 * Foreground Service for continuous conscious app usage monitoring.
 *
 * Runs a lightweight, screen-aware evaluation loop using UsageStatsManager and
 * AppRestrictionEngine. When an active controlled application reaches its daily limit
 * (Normal Mode) or requires intention validation (Strict Mode), it triggers the conscious blocker.
 *
 * Includes battery-saving optimizations:
 * - Automatically pauses polling when the device screen is off (ACTION_SCREEN_OFF).
 * - Dynamically starts/stops based on whether any apps are actively controlled.
 */
class AppUsageMonitoringService : Service() {

    private var handlerThread: HandlerThread? = null
    private var serviceHandler: Handler? = null
    private var screenReceiver: BroadcastReceiver? = null

    private lateinit var appUsageMonitor: AppUsageMonitor
    private lateinit var appRestrictionEngine: AppRestrictionEngine

    companion object {
        const val NOTIFICATION_ID = 8801
        const val CHANNEL_ID = "lnote_monitoring_channel"
        const val ACTION_START = "com.example.lnote.ACTION_START_MONITORING"
        const val ACTION_STOP = "com.example.lnote.ACTION_STOP_MONITORING"
        private const val POLL_INTERVAL_MS = 1000L

        @Volatile
        private var isRunning: Boolean = false

        fun isServiceRunning(): Boolean = isRunning

        fun startService(context: Context) {
            val intent = Intent(context, AppUsageMonitoringService::class.java).apply {
                action = ACTION_START
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ContextCompat.startForegroundService(context, intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                AppUsageDiagnosticLogger.e("Failed to start AppUsageMonitoringService", e)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, AppUsageMonitoringService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                AppUsageDiagnosticLogger.e("Failed to send stop to AppUsageMonitoringService", e)
            }
        }

        /**
         * Reconcile service state: Start if controlled packages exist and usage permission is granted;
         * otherwise stop service.
         */
        fun updateServiceState(context: Context) {
            val prefs = context.getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
            val controlled = prefs.getStringSet("controlled_packages", emptySet()) ?: emptySet()
            val monitor = AppUsageMonitorImpl(context)

            if (controlled.isNotEmpty() && monitor.hasUsageAccess()) {
                startService(context)
            } else {
                if (isRunning) {
                    stopService(context)
                }
            }
        }
    }

    private val monitorRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return

            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            val isInteractive = powerManager?.isInteractive ?: true

            if (isInteractive) {
                try {
                    evaluateForeground()
                } catch (e: Exception) {
                    AppUsageDiagnosticLogger.e("Error during monitoring loop evaluation", e)
                }
            }

            if (isRunning) {
                serviceHandler?.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        appUsageMonitor = AppUsageMonitorImpl(this)
        appRestrictionEngine = AppRestrictionEngineImpl(this, appUsageMonitor)

        registerScreenReceiver()

        handlerThread = HandlerThread("LNoteUsageMonitorThread").apply {
            start()
            serviceHandler = Handler(looper)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_STOP) {
            stopMonitoring()
            stopSelf()
            return START_NOT_STICKY
        }

        startInForeground()

        isRunning = true
        serviceHandler?.removeCallbacks(monitorRunnable)
        serviceHandler?.post(monitorRunnable)

        AppUsageDiagnosticLogger.i("AppUsageMonitoringService started in foreground")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startInForeground() {
        val notification = buildPersistentNotification()
        try {
            if (Build.VERSION.SDK_INT >= 34) { // Android 14+
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { // Android 10-13
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Failed to startForeground with type; falling back", e)
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (fallbackError: Exception) {
                AppUsageDiagnosticLogger.e("Fallback startForeground failed", fallbackError)
            }
        }
    }

    private fun buildPersistentNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "LNote Conscious Usage Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors foreground apps to provide conscious screen time pauses"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingIntentFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("LNote Conscious Usage Active")
            .setContentText("Monitoring mindful habits and app limits")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun evaluateForeground() {
        // Do not trigger if any blocker activity or overlay is actively showing
        if (AppUsageBlockerActivity.isAnyBlockerVisible() || AppUsageBlockerOverlayManager.isShowing()) {
            return
        }

        // Verify if any controlled apps are actually active
        val prefs = getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
        val controlled = prefs.getStringSet("controlled_packages", emptySet()) ?: emptySet()
        if (controlled.isEmpty()) {
            return
        }

        if (!appUsageMonitor.hasUsageAccess()) {
            return
        }

        val fg = appUsageMonitor.getForegroundPackageNow()
        if (fg != null && fg != packageName && controlled.contains(fg)) {
            AppUsageDiagnosticLogger.i("evaluateForeground: detected controlled foreground app [$fg]")
            appRestrictionEngine.evaluateForegroundAndEnforce(fg)
        }
    }

    private fun registerScreenReceiver() {
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> {
                        AppUsageDiagnosticLogger.d("Screen OFF event received")
                    }
                    Intent.ACTION_SCREEN_ON,
                    Intent.ACTION_USER_PRESENT -> {
                        AppUsageDiagnosticLogger.i("Screen ON event received: resuming loop")
                        serviceHandler?.removeCallbacks(monitorRunnable)
                        serviceHandler?.post(monitorRunnable)
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
    }

    private fun stopMonitoring() {
        isRunning = false
        serviceHandler?.removeCallbacks(monitorRunnable)
        handlerThread?.quitSafely()
        handlerThread = null
        serviceHandler = null

        screenReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Ignore receiver not registered
            }
            screenReceiver = null
        }
    }

    override fun onDestroy() {
        stopMonitoring()
        super.onDestroy()
        AppUsageDiagnosticLogger.i("AppUsageMonitoringService destroyed")
    }
}
