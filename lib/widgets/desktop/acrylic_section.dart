import 'package:flutter/material.dart';
import '../../theme/windows_acrylic_theme.dart';

/// Inner section card container for Windows 11 Light Acrylic widgets
class AcrylicSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? backgroundColor;

  const AcrylicSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = WindowsAcrylicTheme.radiusCard,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? WindowsAcrylicTheme.cardAcrylic,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withAlpha(210),
          width: 1.0,
        ),
        boxShadow: WindowsAcrylicTheme.cardShadow,
      ),
      child: child,
    );
  }
}
