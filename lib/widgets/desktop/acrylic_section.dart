import 'package:flutter/material.dart';
import '../../theme/windows_acrylic_theme.dart';

/// Delicate etched glass tray container for desktop widget content (matching Image 2)
class AcrylicSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? backgroundColor;

  const AcrylicSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
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
          color: WindowsAcrylicTheme.cardBorder,
          width: 0.8,
        ),
      ),
      child: child,
    );
  }
}
