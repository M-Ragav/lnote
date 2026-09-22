import 'package:flutter/material.dart';
import '../../theme/windows_acrylic_theme.dart';

/// Compact Windows 11 style icon button with subtle translucent hover state
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;
  final bool isClose;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 28.0,
    this.iconSize = 15.0,
    this.color,
    this.isClose = false,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.color ?? WindowsAcrylicTheme.textSecondary;
    final hoverColor = widget.isClose
        ? WindowsAcrylicTheme.statusOut
        : (widget.color ?? WindowsAcrylicTheme.primary);

    final bgColor = widget.isClose
        ? (_isPressed
            ? WindowsAcrylicTheme.statusOutBg.withAlpha(50)
            : (_isHovered ? WindowsAcrylicTheme.statusOutBg : Colors.transparent))
        : (_isPressed
            ? WindowsAcrylicTheme.lightAccent
            : (_isHovered ? WindowsAcrylicTheme.hoverOverlay : Colors.transparent));

    Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(widget.isClose ? 4.0 : 6.0),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _isHovered ? hoverColor : defaultColor,
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        textStyle: WindowsAcrylicTheme.caption(size: 11, color: Colors.white),
        decoration: BoxDecoration(
          color: const Color(0xE6202020),
          borderRadius: BorderRadius.circular(4),
        ),
        child: button,
      );
    }

    return button;
  }
}
