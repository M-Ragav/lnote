import 'package:flutter/material.dart';

/// Design tokens and typography for Windows 11 Light Acrylic styling
class WindowsAcrylicTheme {
  // ─── Color System ──────────────────────────────────────────
  static const Color primary = Color(0xFF0067C0);
  static const Color primaryHover = Color(0xFF005FB8);
  static const Color lightAccent = Color(0x350067C0);
  static const Color lightAccentHover = Color(0x450067C0);

  // Surface & Acrylic (Luminous Frosted Aero Glass - Matching Reference)
  static const Color surfaceGradientTop = Color(
    0xE0FFFFFF,
  ); // Luminous white top-left highlight
  static const Color surfaceGradientMid = Color(
    0xB2EAF2FA,
  ); // Semi-transparent frosted ice-white body
  static const Color surfaceGradientBottom = Color(
    0x9CD8E8F5,
  ); // Soft aero glass tint at bottom-right
  static const Color borderLight = Color(
    0x80FFFFFF,
  ); // 1px subtle translucent border (low opacity)

  // Inner Sections (Ultra-subtle, non-intrusive glass tint)
  static const Color cardAcrylic = Color(
    0x14FFFFFF,
  ); // Faint translucent glass tint
  static const Color cardBorder = Color(0x35FFFFFF); // Delicate hairline border

  // Typography Colors (Crisp, deep navy/charcoal for bright visibility)
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);

  // Semantic Status (Windows Fluent)
  static const Color statusActive = Color(0xFF107C41);
  static const Color statusActiveBg = Color(0x24107C41);
  static const Color statusOut = Color(0xFFC42B1C);
  static const Color statusOutBg = Color(0x22C42B1C);
  static const Color statusIdleBg = Color(0x45FFFFFF);

  // Dividers & Highlights
  static const Color divider = Color(0x140F172A);
  static const Color hoverOverlay = Color(0x180067C0);

  // ─── Dimensions & Radii ────────────────────────────────────
  static const double radiusSurface = 20.0;
  static const double radiusCard = 20.0;
  static const double radiusPill = 20.0;
  static const double radiusButton = 6.0;

  // ─── Shadows ───────────────────────────────────────────────
  static const List<BoxShadow> ambientShadow = [];
  static const List<BoxShadow> cardShadow = [];

  // ─── Typography Helpers (Segoe UI / System Fallback) ───────
  static const List<String> fontFallbacks = [
    'Segoe UI Variable Text',
    'Segoe UI Variable',
    'Segoe UI',
    '-apple-system',
    'BlinkMacSystemFont',
    'sans-serif',
  ];

  static TextStyle title({
    double size = 13,
    FontWeight weight = FontWeight.w600,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.1,
    );
  }

  static TextStyle subtitle({
    double size = 11,
    FontWeight weight = FontWeight.w400,
    Color color = textSecondary,
  }) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle body({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle timer({
    double size = 26,
    FontWeight weight = FontWeight.w600,
    Color color = textPrimary,
  }) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle caption({
    double size = 10,
    FontWeight weight = FontWeight.w500,
    Color color = textMuted,
  }) {
    return TextStyle(
      fontFamilyFallback: fontFallbacks,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.2,
    );
  }
}
