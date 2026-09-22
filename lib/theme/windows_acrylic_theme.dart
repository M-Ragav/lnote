import 'package:flutter/material.dart';

/// Design tokens and typography for Windows 11 Light Acrylic styling
class WindowsAcrylicTheme {
  // ─── Color System ──────────────────────────────────────────
  static const Color primary = Color(0xFF0067C0);
  static const Color primaryHover = Color(0xFF005FB8);
  static const Color lightAccent = Color(0xFFDCEEFF);
  static const Color lightAccentHover = Color(0xFFCBE5FF);

  // Surface & Acrylic (Light translucent blue/white)
  static const Color surfaceAcrylic = Color(0xD9F3F6FB);
  static const Color surfaceGradientTop = Color(0xEEF8FAFD);
  static const Color surfaceGradientBottom = Color(0xD9F0F4FA);

  // Cards & Sections
  static const Color cardAcrylic = Color(0xB3FFFFFF);
  static const Color cardBorder = Color(0x280067C0);
  static const Color borderLight = Color(0xB3FFFFFF);

  // Typography Colors
  static const Color textPrimary = Color(0xFF202020);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textMuted = Color(0xFF7A8088);

  // Semantic Status (Windows Fluent)
  static const Color statusActive = Color(0xFF107C41);
  static const Color statusActiveBg = Color(0x18107C41);
  static const Color statusOut = Color(0xFFC42B1C);
  static const Color statusOutBg = Color(0x18C42B1C);

  // Dividers & Highlights
  static const Color divider = Color(0x15202020);
  static const Color hoverOverlay = Color(0x0D0067C0);

  // ─── Dimensions & Radii ────────────────────────────────────
  static const double radiusSurface = 18.0;
  static const double radiusCard = 12.0;
  static const double radiusPill = 20.0;
  static const double radiusButton = 6.0;

  // ─── Shadows ───────────────────────────────────────────────
  static const List<BoxShadow> ambientShadow = [
    BoxShadow(
      color: Color(0x0D002040),
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  // ─── Typography Helpers (Segoe UI / System Fallback) ───────
  static const List<String> fontFallbacks = [
    'Segoe UI Variable Text',
    'Segoe UI Variable',
    'Segoe UI',
    '-apple-system',
    'BlinkMacSystemFont',
    'sans-serif',
  ];

  static TextStyle title({double size = 13, FontWeight weight = FontWeight.w600, Color color = textPrimary}) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.1,
    );
  }

  static TextStyle subtitle({double size = 11, FontWeight weight = FontWeight.w400, Color color = textSecondary}) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle body({double size = 12, FontWeight weight = FontWeight.w400, Color color = textPrimary}) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle timer({double size = 26, FontWeight weight = FontWeight.w600, Color color = textPrimary}) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle caption({double size = 10, FontWeight weight = FontWeight.w500, Color color = textMuted}) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.2,
    );
  }
}
