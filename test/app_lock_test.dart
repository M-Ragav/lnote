import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lnote/services/storage_service.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async => '.');
  });

  test('App Lock is disabled by default', () async {
    final storage = StorageService();
    await storage.init();

    expect(storage.isAppLockEnabled, isFalse);
    expect(storage.isBiometricEnabled, isFalse);
  });

  test('Set 4-digit PIN enables App Lock and verifies correctly', () async {
    final storage = StorageService();
    await storage.init();

    // Invalid PIN length
    final failShort = await storage.setAppPin('123');
    expect(failShort, isFalse);
    expect(storage.isAppLockEnabled, isFalse);

    // Valid 4-digit PIN
    final success = await storage.setAppPin('4321', enableBiometric: true);
    expect(success, isTrue);
    expect(storage.isAppLockEnabled, isTrue);
    expect(storage.isBiometricEnabled, isTrue);

    // Verify PIN
    expect(storage.verifyPin('4321'), isTrue);
    expect(storage.verifyPin('0000'), isFalse);
    expect(storage.verifyPin('432'), isFalse);
  });

  test('Change PIN verifies old PIN first', () async {
    final storage = StorageService();
    await storage.init();
    await storage.setAppPin('1111');

    // Wrong current PIN
    final failChange = await storage.changePin(currentPin: '9999', newPin: '2222');
    expect(failChange, isFalse);
    expect(storage.verifyPin('1111'), isTrue);

    // Correct current PIN
    final successChange = await storage.changePin(currentPin: '1111', newPin: '2222');
    expect(successChange, isTrue);
    expect(storage.verifyPin('2222'), isTrue);
    expect(storage.verifyPin('1111'), isFalse);
  });

  test('Disable App Lock removes PIN and clears lock flag', () async {
    final storage = StorageService();
    await storage.init();
    await storage.setAppPin('9876', enableBiometric: true);
    expect(storage.isAppLockEnabled, isTrue);

    // Wrong current PIN
    final failDisable = await storage.disableAppLock(currentPin: '0000');
    expect(failDisable, isFalse);
    expect(storage.isAppLockEnabled, isTrue);

    // Correct current PIN
    final successDisable = await storage.disableAppLock(currentPin: '9876');
    expect(successDisable, isTrue);
    expect(storage.isAppLockEnabled, isFalse);
    expect(storage.isBiometricEnabled, isFalse);
    expect(storage.verifyPin('9876'), isFalse);
  });

  test('Biometric toggle updates state independently', () async {
    final storage = StorageService();
    await storage.init();
    await storage.setAppPin('1234', enableBiometric: false);
    expect(storage.isBiometricEnabled, isFalse);

    await storage.setBiometricEnabled(true);
    expect(storage.isBiometricEnabled, isTrue);

    await storage.setBiometricEnabled(false);
    expect(storage.isBiometricEnabled, isFalse);
  });
}
