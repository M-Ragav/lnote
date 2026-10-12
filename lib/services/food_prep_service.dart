import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food_item.dart';

/// Service to manage Food Preparation alarms and native/in-app floating windows
class FoodPrepService {
  static const MethodChannel _channel =
      MethodChannel('com.example.lnote/food_prep');

  /// Check whether Android 'Display over other apps' (SYSTEM_ALERT_WINDOW) is granted
  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
      return false;
    }
  }

  /// Open Android settings to request 'Display over other apps' permission
  static Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
    }
  }

  /// Schedule or cancel the daily food prep alarm at the specified time
  static Future<void> scheduleDailyAlarm({
    required int hour,
    required int minute,
    required bool enabled,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
      });
    } catch (e) {
      debugPrint('Error scheduling daily alarm: $e');
    }
  }

  /// Trigger the native floating window overlay (over other apps)
  static Future<bool> showNativeFloatingWindow(List<FoodItem> tomorrowFoods) async {
    if (!Platform.isAndroid) return false;
    try {
      final itemsJson = tomorrowFoods
          .map((f) => {
                'id': f.id,
                'name': f.name,
                'count': f.count ?? '',
                'notes': f.notes ?? '',
                'deadline': f.deadline,
                'mealType': f.mealType.displayName,
              })
          .toList();

      final res = await _channel.invokeMethod<bool>('showOverlay', {
        'items': itemsJson,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('Error showing native overlay: $e');
      return false;
    }
  }

  /// Close the native floating window overlay
  static Future<void> hideNativeFloatingWindow() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('hideOverlay');
    } catch (e) {
      debugPrint('Error hiding native overlay: $e');
    }
  }

  /// Tell native alarm to pop up again in 10 minutes (Temporary Skip)
  static Future<void> snooze10Minutes() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('snooze', {'minutes': 10});
    } catch (e) {
      debugPrint('Error snoozing alarm: $e');
    }
  }
}
