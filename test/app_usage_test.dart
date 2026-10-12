import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:lnote/models/app_restriction.dart';
import 'package:lnote/models/usage_session.dart';
import 'package:lnote/models/usage_reason.dart';
import 'package:lnote/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void cleanupFiles() {
    for (final name in ['app_restrictions.json', 'usage_sessions.json', 'usage_reasons.json']) {
      final f = File(name);
      if (f.existsSync()) f.deleteSync();
    }
  }

  setUp(() {
    cleanupFiles();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async => '.');
  });

  tearDown(() {
    cleanupFiles();
  });

  group('AppRestriction Model Tests', () {
    test('Create, copyWith and serialize AppRestriction', () {
      final restriction = AppRestriction(
        packageId: 'com.instagram.android',
        appName: 'Instagram',
        enabled: true,
        mode: UsageMode.normal,
        dailyLimitMinutes: 30,
        allowedPresets: const [5, 10, 15],
        createdAt: '2026-10-06T10:00:00.000',
        updatedAt: '2026-10-06T10:00:00.000',
      );

      expect(restriction.packageId, 'com.instagram.android');
      expect(restriction.mode, UsageMode.normal);
      expect(restriction.dailyLimitMinutes, 30);
      expect(restriction.allowedPresets, [5, 10, 15]);

      final json = restriction.toJson();
      final fromJson = AppRestriction.fromJson(json);

      expect(fromJson.packageId, restriction.packageId);
      expect(fromJson.appName, restriction.appName);
      expect(fromJson.mode, UsageMode.normal);
      expect(fromJson.dailyLimitMinutes, 30);

      final updated = restriction.copyWith(
        mode: UsageMode.strict,
        dailyLimitMinutes: 45,
      );
      expect(updated.mode, UsageMode.strict);
      expect(updated.dailyLimitMinutes, 45);
      expect(updated.packageId, restriction.packageId);
    });

    test('UsageMode display names and descriptions', () {
      expect(UsageMode.normal.displayName, 'Normal');
      expect(UsageMode.strict.displayName, 'Strict');
      expect(UsageMode.normal.description, isNotEmpty);
      expect(UsageMode.strict.description, isNotEmpty);
    });
  });

  group('UsageSession & UsageReason Models', () {
    test('UsageSession lifecycle and serialization', () {
      final session = UsageSession(
        id: 'sess_123',
        packageId: 'com.google.android.youtube',
        appName: 'YouTube',
        mode: 'strict',
        startedAt: '2026-10-06T14:00:00.000',
        expiresAt: '2026-10-06T14:15:00.000',
        requestedDurationMinutes: 15,
        status: SessionStatus.active,
      );

      final json = session.toJson();
      final fromJson = UsageSession.fromJson(json);

      expect(fromJson.id, 'sess_123');
      expect(fromJson.status, SessionStatus.active);
      expect(fromJson.requestedDurationMinutes, 15);

      final completed = session.copyWith(
        status: SessionStatus.completed,
        actualDurationMinutes: 12,
        endedAt: '2026-10-06T14:12:00.000',
      );
      expect(completed.status, SessionStatus.completed);
      expect(completed.actualDurationMinutes, 12);
    });

    test('UsageReason categories and conscious reflection serialization', () {
      final reason = UsageReason(
        id: 'reas_456',
        sessionId: 'sess_123',
        packageId: 'com.google.android.youtube',
        appName: 'YouTube',
        mode: 'strict',
        timestamp: '2026-10-06T14:00:00.000',
        category: ReasonCategory.study,
        customReason: 'Watching Flutter state management tutorial',
        requestedMinutes: 15,
        approvedMinutes: 15,
        wasAllowed: true,
      );

      final json = reason.toJson();
      final fromJson = UsageReason.fromJson(json);

      expect(fromJson.id, 'reas_456');
      expect(fromJson.category, ReasonCategory.study);
      expect(fromJson.category.icon, '📚');
      expect(fromJson.category.displayName, 'Study');
      expect(fromJson.customReason, contains('tutorial'));
      expect(fromJson.wasAllowed, isTrue);
    });
  });

  group('StorageService App Usage Persistence Tests', () {
    test('Add, check, update, and remove app restrictions', () async {
      final storage = StorageService();
      await storage.init();

      expect(storage.isPackageControlled('com.instagram.android'), isFalse);

      final restriction = AppRestriction(
        packageId: 'com.instagram.android',
        appName: 'Instagram',
        enabled: true,
        mode: UsageMode.normal,
        dailyLimitMinutes: 20,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await storage.saveAppRestriction(restriction);

      expect(storage.isPackageControlled('com.instagram.android'), isTrue);
      expect(storage.getRestriction('com.instagram.android')?.dailyLimitMinutes, 20);

      // Toggle enabled
      await storage.toggleRestrictionEnabled('com.instagram.android');
      expect(storage.isPackageControlled('com.instagram.android'), isFalse);

      await storage.toggleRestrictionEnabled('com.instagram.android');
      expect(storage.isPackageControlled('com.instagram.android'), isTrue);

      // Remove restriction
      await storage.removeAppRestriction('com.instagram.android');
      expect(storage.isPackageControlled('com.instagram.android'), isFalse);
      expect(storage.getRestriction('com.instagram.android'), isNull);
    });

    test('Conscious stats calculations', () async {
      final storage = StorageService();
      await storage.init();

      final now = DateTime.now();
      final todayReason1 = UsageReason(
        id: 'r1',
        sessionId: 's1',
        packageId: 'com.twitter.android',
        appName: 'X',
        mode: 'normal',
        timestamp: now.toIso8601String(),
        category: ReasonCategory.work,
        customReason: 'Checking release announcement',
        requestedMinutes: 10,
        approvedMinutes: 10,
        wasAllowed: true,
      );

      final todayReason2 = UsageReason(
        id: 'r2',
        sessionId: 's2',
        packageId: 'com.twitter.android',
        appName: 'X',
        mode: 'strict',
        timestamp: now.toIso8601String(),
        category: ReasonCategory.entertainment,
        customReason: 'Boredom',
        requestedMinutes: 15,
        approvedMinutes: 0,
        wasAllowed: false,
      );

      await storage.addUsageReason(todayReason1);
      await storage.addUsageReason(todayReason2);

      final stats = storage.getTodayConsciousStats();
      expect(stats['totalRequests'], 2);
      expect(stats['approved'], 1);
      expect(stats['denied'], 1);
      expect(stats['extraApprovedMinutes'], 10);
    });
  });
}
