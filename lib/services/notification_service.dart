import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Service to trigger local and cross-device push notifications
class NotificationService {
  static const MethodChannel _channel = MethodChannel('com.example.lnote/widgets');

  /// Fire a native notification on this device (Android)
  static Future<bool> showLocalNotification({
    required String title,
    required String message,
  }) async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<bool>('sendNotification', {
          'title': title,
          'message': message,
        });
        return result ?? true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Post a notification to the Python backend so the mobile phone receives it
  static Future<bool> sendBackendNotification({
    required String backendUrl,
    required String title,
    required String message,
  }) async {
    try {
      final baseUrl = backendUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseUrl/api/notify');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 4));

      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Poll backend for pending notifications and deliver them locally on Android
  static Future<void> checkAndDeliverBackendNotifications(String backendUrl) async {
    if (!Platform.isAndroid) return;

    try {
      final baseUrl = backendUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$baseUrl/api/notifications');
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = data['notifications'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final ackIds = <int>[];
          for (final item in list) {
            final id = item['id'] as int;
            final title = item['title'] as String? ?? 'LNote Alert';
            final message = item['message'] as String? ?? '';
            await showLocalNotification(title: title, message: message);
            ackIds.add(id);
          }

          if (ackIds.isNotEmpty) {
            final ackUri = Uri.parse('$baseUrl/api/notifications/ack');
            await http.post(
              ackUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'ids': ackIds}),
            ).timeout(const Duration(seconds: 3));
          }
        }
      }
    } catch (_) {
      // Ignored if server unreachable
    }
  }
}
