import 'dart:io';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Helper service for Biometric Verification (Fingerprint, Face, Windows Hello)
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if hardware supports biometrics and device has biometric credentials enrolled
  static Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Get list of available biometric sensors
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Return user-friendly name for the primary biometric method
  static Future<String> getBiometricName() async {
    try {
      final types = await getAvailableBiometrics();
      if (types.contains(BiometricType.face)) {
        return 'Face Unlock';
      } else if (types.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (Platform.isWindows) {
        return 'Windows Hello';
      }
      return 'Biometrics';
    } catch (_) {
      return 'Biometrics';
    }
  }

  /// Prompt native biometric authentication dialog
  static Future<bool> authenticate({
    String reason = 'Unlock LNote with your biometrics',
  }) async {
    try {
      final can = await canAuthenticate();
      if (!can) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
