package com.example.lnote

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.io.ByteArrayOutputStream
import java.util.Calendar

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.lnote/widgets"
    private val FOOD_PREP_CHANNEL = "com.example.lnote/food_prep"
    private val APP_USAGE_CHANNEL = "com.example.lnote/app_usage"
    private val NOTIF_CHANNEL_ID = "lnote_alerts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgets" -> {
                    CalendarWidgetProvider.updateAll(this)
                    DashboardWidgetProvider.updateAll(this)
                    result.success(true)
                }
                "sendNotification" -> {
                    val title = call.argument<String>("title") ?: "LNote Alert"
                    val message = call.argument<String>("message") ?: "This is a test notification."
                    showNotification(title, message)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOOD_PREP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "scheduleAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 21
                    val minute = call.argument<Int>("minute") ?: 0
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    if (enabled) {
                        FoodPrepAlarmReceiver.scheduleAlarm(this, hour, minute)
                    } else {
                        FoodPrepAlarmReceiver.cancelAlarm(this)
                    }
                    result.success(true)
                }
                "showOverlay" -> {
                    val items = call.argument<List<Map<String, Any>>>("items")
                    val itemsJson = if (items != null) JSONArray(items).toString() else ""
                    val intent = Intent(this, FoodPrepOverlayService::class.java).apply {
                        action = FoodPrepOverlayService.ACTION_SHOW
                        putExtra(FoodPrepOverlayService.EXTRA_ITEMS_JSON, itemsJson)
                    }
                    try {
                        startService(intent)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "hideOverlay" -> {
                    val intent = Intent(this, FoodPrepOverlayService::class.java).apply {
                        action = FoodPrepOverlayService.ACTION_CLOSE
                    }
                    try {
                        startService(intent)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "snooze" -> {
                    FoodPrepOverlayService.handleTempSkip(this)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        val appUsageMonitor: AppUsageMonitor = AppUsageMonitorImpl(this)
        val appRestrictionEngine: AppRestrictionEngine = AppRestrictionEngineImpl(this, appUsageMonitor)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_USAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> {
                    result.success(appUsageMonitor.hasUsageAccess())
                }
                "requestUsageStatsPermission" -> {
                    appUsageMonitor.openUsageAccessSettings()
                    result.success(true)
                }
                "getForegroundPackageNow" -> {
                    result.success(appUsageMonitor.getForegroundPackageNow())
                }
                "getRestrictionState" -> {
                    val pkg = call.argument<String>("packageId") ?: ""
                    val state = appRestrictionEngine.getRestrictionState(pkg)
                    result.success(state.name)
                }
                "getRemainingDailyUsage" -> {
                    val pkg = call.argument<String>("packageId") ?: ""
                    val remaining = appRestrictionEngine.getRemainingDailyUsage(pkg)
                    result.success(remaining)
                }
                "isControlled" -> {
                    val pkg = call.argument<String>("packageId") ?: ""
                    result.success(appRestrictionEngine.isControlled(pkg))
                }
                "isStrict" -> {
                    val pkg = call.argument<String>("packageId") ?: ""
                    result.success(appRestrictionEngine.isStrict(pkg))
                }
                "evaluateForegroundAndEnforce" -> {
                    val state = appRestrictionEngine.evaluateForegroundAndEnforce()
                    result.success(state.name)
                }
                "getMonitoringHealth" -> {
                    val health = appRestrictionEngine.getMonitoringHealth()
                    result.success(health.name)
                }
                "getHealthDiagnosticInfo" -> {
                    val info = appRestrictionEngine.getHealthDiagnosticInfo()
                    result.success(info)
                }
                "hasAccessibilityPermission" -> {
                    // Accessibility is no longer used; return true to satisfy legacy checks.
                    result.success(true)
                }
                "requestAccessibilityPermission" -> {
                    // No-op: accessibility is no longer requested.
                    result.success(true)
                }
                "openAppDetailsSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "isBatteryOptimizationIgnored" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        result.success(pm?.isIgnoringBatteryOptimizations(packageName) ?: false)
                    } else {
                        result.success(true)
                    }
                }
                "requestIgnoreBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                }
                "hasOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "getInstalledApps" -> {
                    Thread {
                        val pm = packageManager
                        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                            addCategory(Intent.CATEGORY_LAUNCHER)
                        }
                        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
                        val appsList = mutableListOf<Map<String, Any?>>()
                        for (info in resolveInfos) {
                            val pkg = info.activityInfo.packageName
                            if (pkg == packageName) continue
                            val label = info.loadLabel(pm).toString()
                            var iconBytes: ByteArray? = null
                            try {
                                val drawable = info.loadIcon(pm)
                                val bitmap = if (drawable is BitmapDrawable) {
                                    drawable.bitmap
                                } else {
                                    val bmp = Bitmap.createBitmap(
                                        drawable.intrinsicWidth.coerceAtLeast(1),
                                        drawable.intrinsicHeight.coerceAtLeast(1),
                                        Bitmap.Config.ARGB_8888
                                    )
                                    val canvas = Canvas(bmp)
                                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                                    drawable.draw(canvas)
                                    bmp
                                }
                                val stream = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                                iconBytes = stream.toByteArray()
                            } catch (e: Exception) {
                                // Fallback icon null
                            }
                            appsList.add(mapOf(
                                "packageName" to pkg,
                                "appName" to label,
                                "icon" to iconBytes
                            ))
                        }
                        runOnUiThread {
                            result.success(appsList)
                        }
                    }.start()
                }
                "getDailyUsageStats" -> {
                    val year = call.argument<Int>("year") ?: Calendar.getInstance().get(Calendar.YEAR)
                    val month = call.argument<Int>("month") ?: (Calendar.getInstance().get(Calendar.MONTH) + 1)
                    val day = call.argument<Int>("day") ?: Calendar.getInstance().get(Calendar.DAY_OF_MONTH)
                    val cal = Calendar.getInstance().apply {
                        set(Calendar.YEAR, year)
                        set(Calendar.MONTH, month - 1)
                        set(Calendar.DAY_OF_MONTH, day)
                        set(Calendar.HOUR_OF_DAY, 0)
                        set(Calendar.MINUTE, 0)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }
                    val start = cal.timeInMillis
                    val end = start + (24 * 60 * 60 * 1000L)
                    val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                    val usageMap = mutableMapOf<String, Long>()
                    if (usageStatsManager != null) {
                        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
                        for (s in stats) {
                            if (s.totalTimeInForeground > 0) {
                                usageMap[s.packageName] = (usageMap[s.packageName] ?: 0L) + s.totalTimeInForeground
                            }
                        }
                    }
                    result.success(usageMap)
                }
                "syncRestrictions" -> {
                    val controlled = call.argument<List<String>>("controlledPackages") ?: emptyList()
                    val strict = call.argument<List<String>>("strictPackages") ?: emptyList()
                    val prefs = getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
                    prefs.edit()
                        .remove("controlled_packages")
                        .remove("strict_packages")
                        .putStringSet("controlled_packages", controlled.toSet())
                        .putStringSet("strict_packages", strict.toSet())
                        .commit()
                    AppUsageDiagnosticLogger.i("Synced restrictions: ${controlled.size} controlled, ${strict.size} strict")
                    AppUsageMonitoringService.updateServiceState(this)
                    result.success(true)
                }
                "grantTemporaryAccess" -> {
                    val pkg = call.argument<String>("packageId")
                    val duration = call.argument<Int>("durationMinutes") ?: 10
                    val reason = call.argument<String>("reason") ?: "Conscious temporary access"
                    if (pkg != null) {
                        val durationMs = duration * 60 * 1000L
                        val res = appRestrictionEngine.requestTemporaryAccess(pkg, reason, durationMs)
                        val appName = try {
                            val appInfo = packageManager.getApplicationInfo(pkg, 0)
                            packageManager.getApplicationLabel(appInfo).toString()
                        } catch (e: Exception) {
                            pkg.substringAfterLast('.')
                        }
                        AppUsageAlarmReceiver.scheduleSessionExpireAlarm(this, pkg, appName, res.expirationTimestamp)
                        AppUsageDiagnosticLogger.i("Granted temporary access via Flutter channel for [$pkg]: ${duration}m")
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "revokeTemporaryAccess" -> {
                    val pkg = call.argument<String>("packageId")
                    if (pkg != null) {
                        appRestrictionEngine.expireTemporaryAccess(pkg)
                        AppUsageAlarmReceiver.cancelSessionExpireAlarm(this, pkg)
                        AppUsageDiagnosticLogger.i("Revoked temporary access for [$pkg]")
                    }
                    result.success(true)
                }
                "showBlockerOverlay" -> {
                    val pkg = call.argument<String>("packageId")
                    val appName = call.argument<String>("appName")
                    val mode = call.argument<String>("mode") ?: "normal"
                    if (pkg != null) {
                        val intent = Intent(this, AppUsageBlockerActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                    Intent.FLAG_ACTIVITY_NO_ANIMATION
                            putExtra(AppUsageBlockerActivity.EXTRA_PACKAGE_NAME, pkg)
                            putExtra(AppUsageBlockerActivity.EXTRA_APP_NAME, appName)
                            putExtra(AppUsageBlockerActivity.EXTRA_MODE, mode)
                        }
                        try {
                            startActivity(intent)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                    result.success(true)
                }
                "hideBlockerOverlay" -> {
                    result.success(true)
                }
                "updateDailyLimits" -> {
                    val limits = call.argument<Map<String, Int>>("limits") ?: emptyMap()
                    val prefs = getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    for ((pkg, limit) in limits) {
                        editor.putInt("daily_limit_$pkg", limit)
                    }
                    editor.apply()
                    result.success(true)
                }
                "startMonitoringService" -> {
                    AppUsageMonitoringService.startService(this)
                    result.success(true)
                }
                "stopMonitoringService" -> {
                    AppUsageMonitoringService.stopService(this)
                    result.success(true)
                }
                "isMonitoringServiceRunning" -> {
                    result.success(AppUsageMonitoringService.isServiceRunning())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun showNotification(title: String, message: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create channel on Android O (API 26) and higher
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIF_CHANNEL_ID,
                "LNote Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "LNote attendance and session notifications"
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Request runtime permission on Android 13+ (TIRAMISU)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    101
                )
            }
        }

        val notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()

        notificationManager.notify((System.currentTimeMillis() % 100000).toInt(), notification)
    }

    override fun onResume() {
        super.onResume()
        CalendarWidgetProvider.updateAll(this)
        DashboardWidgetProvider.updateAll(this)
        AppUsageAlarmReceiver.scheduleMidnightRollover(this)
        AppUsageMonitoringService.updateServiceState(this)
    }
}
