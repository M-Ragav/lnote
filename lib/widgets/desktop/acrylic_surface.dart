import 'package:flutter/material.dart';
import '../../theme/windows_acrylic_theme.dart';

/// Outer container providing the ONE unified Windows 11 Frosted Glass surface
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
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: WindowsAcrylicTheme.borderLight,
          width: 1.0,
        ),
        gradient: const LinearGradient(
          colors: [
            WindowsAcrylicTheme.surfaceGradientTop,
            WindowsAcrylicTheme.surfaceGradientMid,
            WindowsAcrylicTheme.surfaceGradientBottom,
          ],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x60FFFFFF),
            blurRadius: 1,
            spreadRadius: 0.5,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
