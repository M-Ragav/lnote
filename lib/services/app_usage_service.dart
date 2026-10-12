import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Lightweight info about an installed app retrieved from the native platform.
class InstalledAppInfo {
  final String packageName;
  final String appName;
  final Uint8List? iconBytes;

  const InstalledAppInfo({
    required this.packageName,
    required this.appName,
    this.iconBytes,
  });
}

/// Platform channel bridge for App Usage Control.
///
/// Handles communication with native Android UsageStatsManager,
/// PackageManager, and overlay / blocking services.
class AppUsageService {
  static const _channel = MethodChannel('com.example.lnote/app_usage');

  // ─── Permissions ────────────────────────────────────────

  /// Check if the PACKAGE_USAGE_STATS permission is granted.
  static Future<bool> hasUsageStatsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsageStatsPermission') ?? false;
    } catch (e) {
      debugPrint('AppUsageService: hasUsageStatsPermission error: $e');
      return false;
    }
  }

  /// Open system settings to grant PACKAGE_USAGE_STATS.
  static Future<void> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } catch (e) {
      debugPrint('AppUsageService: requestUsageStatsPermission error: $e');
    }
  }

  /// Deprecated: Accessibility service is no longer used. Returns true for backward compatibility.
  static Future<bool> hasAccessibilityPermission() async {
    return true;
  }

  /// Deprecated: Accessibility service is no longer used. No-op.
  static Future<void> requestAccessibilityPermission() async {}

  /// Check if overlay (SYSTEM_ALERT_WINDOW) permission is granted.
  static Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (e) {
      debugPrint('AppUsageService: hasOverlayPermission error: $e');
      return false;
    }
  }

  /// Open system settings to grant overlay permission.
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('AppUsageService: requestOverlayPermission error: $e');
    }
  }

  /// Check if the app is exempt from OS battery optimization (Doze mode).
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
    } catch (e) {
      debugPrint('AppUsageService: isBatteryOptimizationIgnored error: $e');
      return false;
    }
  }

  /// Request exemption from battery optimization.
  static Future<void> requestIgnoreBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (e) {
      debugPrint('AppUsageService: requestIgnoreBatteryOptimization error: $e');
    }
  }

  /// Open Android App Info settings (Required for Android 13+ "Allow restricted settings").
  static Future<void> openAppDetailsSettings() async {
    try {
      await _channel.invokeMethod('openAppDetailsSettings');
    } catch (e) {
      debugPrint('AppUsageService: openAppDetailsSettings error: $e');
    }
  }

  // ─── Installed Apps ─────────────────────────────────────

  /// Retrieve list of user-installed (launchable) apps from PackageManager.
  static Future<List<InstalledAppInfo>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (result == null) return [];
      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        Uint8List? icon;
        if (map['icon'] != null) {
          icon = Uint8List.fromList(List<int>.from(map['icon']));
        }
        return InstalledAppInfo(
          packageName: map['packageName'] as String,
          appName: map['appName'] as String,
          iconBytes: icon,
        );
      }).toList();
    } catch (e) {
      debugPrint('AppUsageService: getInstalledApps error: $e');
      return [];
    }
  }

  // ─── Usage Stats ────────────────────────────────────────

  /// Get daily usage in milliseconds for all packages on a given date.
  /// Returns `Map<String, int>` (packageName -> totalForegroundMs).
  static Future<Map<String, int>> getDailyUsageStats(DateTime date) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDailyUsageStats',
        {
          'year': date.year,
          'month': date.month,
          'day': date.day,
        },
      );
      if (result == null) return {};
      return result.map((k, v) => MapEntry(k as String, v as int));
    } catch (e) {
      debugPrint('AppUsageService: getDailyUsageStats error: $e');
      return {};
    }
  }

  /// Query the currently active foreground package name using recent UsageEvents.
  static Future<String?> getForegroundPackageNow() async {
    try {
      return await _channel.invokeMethod<String>('getForegroundPackageNow');
    } catch (e) {
      debugPrint('AppUsageService: getForegroundPackageNow error: $e');
      return null;
    }
  }

  // ─── Restriction Sync ──────────────────────────────────

  /// Push the full set of controlled package names and their modes to native.
  /// Push the full set of controlled package names and their modes to native.
  /// The native restriction engine reads these from SharedPreferences to decide
  /// whether to enforce restrictions.
  static Future<void> syncRestrictions({
    required List<String> controlledPackages,
    required List<String> strictPackages,
  }) async {
    try {
      await _channel.invokeMethod('syncRestrictions', {
        'controlledPackages': controlledPackages,
        'strictPackages': strictPackages,
      });
    } catch (e) {
      debugPrint('AppUsageService: syncRestrictions error: $e');
    }
  }

  // ─── Restriction Engine State ──────────────────────────

  /// Query current restriction state for a package ('UNCONTROLLED', 'ALLOWED', 'RESTRICTED', 'NEEDS_REASON', 'TEMP_ACCESS').
  static Future<String> getRestrictionState(String packageId) async {
    try {
      return await _channel.invokeMethod<String>('getRestrictionState', {'packageId': packageId}) ?? 'UNCONTROLLED';
    } catch (e) {
      debugPrint('AppUsageService: getRestrictionState error: $e');
      return 'UNCONTROLLED';
    }
  }

  /// Get remaining daily usage in milliseconds for a controlled package.
  static Future<int> getRemainingDailyUsage(String packageId) async {
    try {
      return await _channel.invokeMethod<int>('getRemainingDailyUsage', {'packageId': packageId}) ?? 0;
    } catch (e) {
      debugPrint('AppUsageService: getRemainingDailyUsage error: $e');
      return 0;
    }
  }

  /// Check whether a package is marked as controlled in the native restriction engine.
  static Future<bool> isControlled(String packageId) async {
    try {
      return await _channel.invokeMethod<bool>('isControlled', {'packageId': packageId}) ?? false;
    } catch (e) {
      debugPrint('AppUsageService: isControlled error: $e');
      return false;
    }
  }

  /// Check whether a package is configured for Strict Mode in the native restriction engine.
  static Future<bool> isStrict(String packageId) async {
    try {
      return await _channel.invokeMethod<bool>('isStrict', {'packageId': packageId}) ?? false;
    } catch (e) {
      debugPrint('AppUsageService: isStrict error: $e');
      return false;
    }
  }

  /// Evaluate current foreground app against restriction engine and trigger conscious blocker if restricted.
  static Future<String> evaluateForegroundAndEnforce() async {
    try {
      return await _channel.invokeMethod<String>('evaluateForegroundAndEnforce') ?? 'UNCONTROLLED';
    } catch (e) {
      debugPrint('AppUsageService: evaluateForegroundAndEnforce error: $e');
      return 'UNCONTROLLED';
    }
  }

  /// Query monitoring health state ('ACTIVE', 'DEGRADED_PERMISSION_MISSING', 'DEGRADED_SERVICE_UNAVAILABLE', 'DEGRADED_DATA_STALE', 'RECOVERED').
  static Future<String> getMonitoringHealth() async {
    try {
      return await _channel.invokeMethod<String>('getMonitoringHealth') ?? 'DEGRADED_PERMISSION_MISSING';
    } catch (e) {
      debugPrint('AppUsageService: getMonitoringHealth error: $e');
      return 'DEGRADED_PERMISSION_MISSING';
    }
  }

  /// Retrieve diagnostic health snapshot from native restriction engine.
  static Future<Map<String, dynamic>> getHealthDiagnosticInfo() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getHealthDiagnosticInfo');
      if (res == null) return {};
      return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('AppUsageService: getHealthDiagnosticInfo error: $e');
      return {};
    }
  }

  // ─── Monitoring Service Control ────────────────────────

  /// Explicitly start the foreground monitoring service.
  static Future<bool> startMonitoringService() async {
    try {
      return await _channel.invokeMethod<bool>('startMonitoringService') ?? false;
    } catch (e) {
      debugPrint('AppUsageService: startMonitoringService error: $e');
      return false;
    }
  }

  /// Explicitly stop the foreground monitoring service.
  static Future<bool> stopMonitoringService() async {
    try {
      return await _channel.invokeMethod<bool>('stopMonitoringService') ?? false;
    } catch (e) {
      debugPrint('AppUsageService: stopMonitoringService error: $e');
      return false;
    }
  }

  /// Check whether the foreground monitoring service is currently active.
  static Future<bool> isMonitoringServiceRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isMonitoringServiceRunning') ?? false;
    } catch (e) {
      debugPrint('AppUsageService: isMonitoringServiceRunning error: $e');
      return false;
    }
  }

  // ─── Temporary Access ──────────────────────────────────

  /// Grant temporary access for a package for N minutes.
  /// Sets an exact alarm that re-blocks the app when the session expires.
  static Future<void> grantTemporaryAccess({
    required String packageId,
    required int durationMinutes,
    String? reason,
  }) async {
    try {
      await _channel.invokeMethod('grantTemporaryAccess', {
        'packageId': packageId,
        'durationMinutes': durationMinutes,
        'reason': reason ?? 'Conscious temporary access',
      });
    } catch (e) {
      debugPrint('AppUsageService: grantTemporaryAccess error: $e');
    }
  }

  /// Revoke temporary access immediately for a package.
  static Future<void> revokeTemporaryAccess(String packageId) async {
    try {
      await _channel.invokeMethod('revokeTemporaryAccess', {
        'packageId': packageId,
      });
    } catch (e) {
      debugPrint('AppUsageService: revokeTemporaryAccess error: $e');
    }
  }

  // ─── Overlay ────────────────────────────────────────────

  /// Show the conscious-intervention overlay for a specific app.
  static Future<void> showBlockerOverlay({
    required String packageId,
    required String appName,
    required String mode,
    required List<int> presets,
  }) async {
    try {
      await _channel.invokeMethod('showBlockerOverlay', {
        'packageId': packageId,
        'appName': appName,
        'mode': mode,
        'presets': presets,
      });
    } catch (e) {
      debugPrint('AppUsageService: showBlockerOverlay error: $e');
    }
  }

  /// Hide the blocker overlay.
  static Future<void> hideBlockerOverlay() async {
    try {
      await _channel.invokeMethod('hideBlockerOverlay');
    } catch (e) {
      debugPrint('AppUsageService: hideBlockerOverlay error: $e');
    }
  }

  /// Update usage limit data on native side for daily tracking.
  static Future<void> updateDailyLimits(Map<String, int> packageLimits) async {
    try {
      await _channel.invokeMethod('updateDailyLimits', {
        'limits': packageLimits,
      });
    } catch (e) {
      debugPrint('AppUsageService: updateDailyLimits error: $e');
    }
  }
}
