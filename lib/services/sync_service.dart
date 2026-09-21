import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/attendance_day.dart';
import '../models/skill.dart';
import '../models/user_profile.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

class HealthResult {
  final bool isOk;
  final String? version;
  final int totalDays;
  final int totalSessions;
  final String? error;
  final Duration? latency;

  const HealthResult({
    required this.isOk,
    this.version,
    this.totalDays = 0,
    this.totalSessions = 0,
    this.error,
    this.latency,
  });
}

class SyncDataResult {
  final bool success;
  final String? error;
  final List<AttendanceDay>? attendanceDays;
  final List<Skill>? skills;
  final UserProfile? profile;
  final DateTime? serverTimestamp;

  const SyncDataResult({
    required this.success,
    this.error,
    this.attendanceDays,
    this.skills,
    this.profile,
    this.serverTimestamp,
  });
}

class SyncService {
  /// Clean and normalize the backend URL (e.g., adding http:// if missing, removing trailing slashes)
  static String normalizeUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Ping the backend health endpoint to check connection and response time
  static Future<HealthResult> checkHealth(String rawUrl) async {
    final baseUrl = normalizeUrl(rawUrl);
    if (baseUrl.isEmpty) {
      return const HealthResult(isOk: false, error: 'URL cannot be empty');
    }

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$baseUrl/api/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return HealthResult(
          isOk: true,
          version: data['version'] as String?,
          totalDays: data['totalDays'] as int? ?? 0,
          totalSessions: data['totalSessions'] as int? ?? 0,
          latency: stopwatch.elapsed,
        );
      } else {
        return HealthResult(
          isOk: false,
          error: 'Server responded with status ${response.statusCode}',
          latency: stopwatch.elapsed,
        );
      }
    } on SocketException catch (e) {
      return HealthResult(
        isOk: false,
        error: 'Cannot reach server: ${e.message}. Ensure backend is running and both devices share Wi-Fi.',
      );
    } on TimeoutException {
      return const HealthResult(
        isOk: false,
        error: 'Connection timed out (4s). Check the IP address and firewall.',
      );
    } catch (e) {
      return HealthResult(
        isOk: false,
        error: 'Connection error: $e',
      );
    }
  }

  /// Perform bi-directional synchronization with backend
  static Future<SyncDataResult> syncWithBackend({
    required String rawUrl,
    required List<AttendanceDay> localDays,
    required List<Skill> localSkills,
    UserProfile? localProfile,
    String? deviceName,
  }) async {
    final baseUrl = normalizeUrl(rawUrl);
    if (baseUrl.isEmpty) {
      return const SyncDataResult(success: false, error: 'Backend URL is not set');
    }

    final effectiveDeviceName = deviceName ??
        (Platform.isWindows
            ? 'Windows Laptop'
            : (Platform.isAndroid ? 'Android Mobile' : 'Device'));

    final payload = {
      'deviceId': effectiveDeviceName.toLowerCase().replaceAll(' ', '_'),
      'deviceName': effectiveDeviceName,
      'clientTimestamp': DateTime.now().toUtc().toIso8601String(),
      'attendanceDays': localDays.map((d) => d.toJson()).toList(),
      'skills': localSkills.map((s) => s.toJson()).toList(),
      if (localProfile != null) 'profile': localProfile.toJson(),
    };

    try {
      final uri = Uri.parse('$baseUrl/api/sync');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        final List<AttendanceDay> remoteDays = (data['attendanceDays'] as List<dynamic>? ?? [])
            .map((j) => AttendanceDay.fromJson(j as Map<String, dynamic>))
            .toList();

        final List<Skill> remoteSkills = (data['skills'] as List<dynamic>? ?? [])
            .map((j) => Skill.fromJson(j as Map<String, dynamic>))
            .toList();

        UserProfile? remoteProfile;
        if (data['profile'] != null) {
          remoteProfile = UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
        }

        DateTime? timestamp;
        if (data['serverTimestamp'] != null) {
          timestamp = DateTime.tryParse(data['serverTimestamp'] as String);
        }

        return SyncDataResult(
          success: true,
          attendanceDays: remoteDays,
          skills: remoteSkills,
          profile: remoteProfile,
          serverTimestamp: timestamp,
        );
      } else {
        return SyncDataResult(
          success: false,
          error: 'Server sync returned HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on SocketException catch (e) {
      return SyncDataResult(
        success: false,
        error: 'Network error: ${e.message}',
      );
    } on TimeoutException {
      return const SyncDataResult(
        success: false,
        error: 'Sync timed out. Check network connection.',
      );
    } catch (e) {
      return SyncDataResult(
        success: false,
        error: 'Sync error: $e',
      );
    }
  }
}
