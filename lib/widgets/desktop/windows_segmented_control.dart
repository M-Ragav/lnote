import 'package:flutter/material.dart';
import '../../theme/windows_acrylic_theme.dart';

/// Windows 11 style segmented pill control with soft translucent blue active highlight
class WindowsSegmentedControl extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final List<WindowsSegmentItem> items;

  const WindowsSegmentedControl({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x10000000),
        borderRadius: BorderRadius.circular(WindowsAcrylicTheme.radiusPill),
        border: Border.all(
          color: Colors.white.withAlpha(180),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isSelected = item.value == selected;
          return _SegmentItem(
            label: item.label,
            isSelected: isSelected,
            onTap: () => onChanged(item.value),
          );
        }).toList(),
      ),
    );
  }
}

class WindowsSegmentItem {
  final String value;
  final String label;

  const WindowsSegmentItem({
    required this.value,
    required this.label,
  });
}

class _SegmentItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SegmentItem> createState() => _SegmentItemState();
}

class _SegmentItemState extends State<_SegmentItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? WindowsAcrylicTheme.lightAccent
        : (_isHovered ? const Color(0x0C000000) : Colors.transparent);

    final textColor = widget.isSelected
        ? WindowsAcrylicTheme.primary
        : (_isHovered ? WindowsAcrylicTheme.textPrimary : WindowsAcrylicTheme.textSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(WindowsAcrylicTheme.radiusPill),
            border: widget.isSelected
                ? Border.all(
                    color: WindowsAcrylicTheme.primary.withAlpha(35),
                    width: 0.5,
                  )
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamilyFallback: WindowsAcrylicTheme.fontFallbacks,
              fontSize: 11,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
