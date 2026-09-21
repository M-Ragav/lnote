import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Color Palette ───────────────────────────────────────
  static const Color _accentTeal = Color(0xFF00C9A7);
  static const Color _accentCyan = Color(0xFF00D4FF);
  static const Color _darkBg = Color(0xFF0D0D0F);
  static const Color _darkSurface = Color(0xFF1A1A1F);
  static const Color _darkCard = Color(0xFF222228);
  static const Color _darkBorder = Color(0xFF2A2A32);
  static const Color _successGreen = Color(0xFF4ADE80);
  static const Color _errorRed = Color(0xFFEF4444);
  static const Color _warningAmber = Color(0xFFFBBF24);

  static const Color _lightBg = Color(0xFFF5F5F7);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFF0F0F4);
  static const Color _lightBorder = Color(0xFFE0E0E6);

  // ─── Gradient ────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [_accentTeal, _accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient startGradient = LinearGradient(
    colors: [_accentTeal, Color(0xFF00E5C3)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient endGradient = LinearGradient(
    colors: [_errorRed, Color(0xFFFF6B6B)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const Color successGreen = _successGreen;
  static const Color errorRed = _errorRed;
  static const Color warningAmber = _warningAmber;
  static const Color accentTeal = _accentTeal;
  static const Color accentCyan = _accentCyan;

  // ─── Dark Theme ──────────────────────────────────────────
  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      primaryColor: _accentTeal,
      colorScheme: const ColorScheme.dark(
        primary: _accentTeal,
        secondary: _accentCyan,
        surface: _darkSurface,
        error: _errorRed,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        outline: _darkBorder,
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorder, width: 0.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurface,
        indicatorColor: _accentTeal.withAlpha(30),
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _accentTeal,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _accentTeal, size: 24);
          }
          return const IconThemeData(color: Colors.white54, size: 24);
        }),
      ),
      textTheme: _buildTextTheme(Colors.white),
      iconTheme: const IconThemeData(color: Colors.white70),
      dividerTheme: const DividerThemeData(color: _darkBorder, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkCard,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Light Theme ─────────────────────────────────────────
  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBg,
      primaryColor: _accentTeal,
      colorScheme: const ColorScheme.light(
        primary: _accentTeal,
        secondary: _accentCyan,
        surface: _lightSurface,
        error: _errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1A1A1F),
        outline: _lightBorder,
      ),
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _lightBorder, width: 0.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1F),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: _accentTeal.withAlpha(20),
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _accentTeal,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black45,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _accentTeal, size: 24);
          }
          return const IconThemeData(color: Colors.black45, size: 24);
        }),
      ),
      textTheme: _buildTextTheme(const Color(0xFF1A1A1F)),
      iconTheme: const IconThemeData(color: Color(0xFF6B7280)),
      dividerTheme: const DividerThemeData(color: _lightBorder, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightSurface,
        contentTextStyle: GoogleFonts.inter(color: const Color(0xFF1A1A1F), fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Text Theme ──────────────────────────────────────────
  static TextTheme _buildTextTheme(Color baseColor) {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: baseColor,
        letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: baseColor,
        letterSpacing: -1,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: baseColor.withAlpha(178),
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: baseColor.withAlpha(200),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: baseColor.withAlpha(153),
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: baseColor.withAlpha(128),
        letterSpacing: 0.5,
      ),
    );
  }
}
