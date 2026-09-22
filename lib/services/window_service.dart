import 'dart:io';
import 'package:flutter/services.dart';

/// Platform channel bridge to handle native Win32 window operations (dragging, closing)
class WindowService {
  static const MethodChannel _channel = MethodChannel('com.example.lnote/window');

  /// Starts native OS window dragging (WM_NCLBUTTONDOWN with HTCAPTION)
  static Future<void> startDragging() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('startDragging');
    } catch (_) {
      // Ignored if platform channel is not wired or on non-Windows
    }
  }

  /// Closes the native application window
  static Future<void> closeWindow() async {
    if (!Platform.isWindows) {
      SystemNavigator.pop();
      return;
    }
    try {
      await _channel.invokeMethod('closeWindow');
    } catch (_) {
      exit(0);
    }
  }
}
