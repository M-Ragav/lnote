import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/windows_acrylic_theme.dart';

/// Outer container providing Windows 11 Light Acrylic surface with real-time backdrop blur
class AcrylicSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const AcrylicSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = WindowsAcrylicTheme.radiusSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: WindowsAcrylicTheme.ambientShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  WindowsAcrylicTheme.surfaceGradientTop,
                  WindowsAcrylicTheme.surfaceGradientBottom,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withAlpha(165),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
