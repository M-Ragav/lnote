import 'package:flutter/material.dart';
import '../../services/window_service.dart';
import '../../theme/windows_acrylic_theme.dart';
import 'glass_icon_button.dart';

/// Minimal Windows 11 draggable header for desktop widgets
class WidgetHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSync;
  final VoidCallback? onRefresh;
  final VoidCallback? onClose;
  final bool isSyncing;

  const WidgetHeader({
    super.key,
    this.title = 'LNote',
    this.onSync,
    this.onRefresh,
    this.onClose,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => WindowService.startDragging(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 5, 8, 3),
        color: Colors.transparent,
        child: Row(
          children: [
            // Left: Brand logo & Title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: WindowsAcrylicTheme.primary,
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'L',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: WindowsAcrylicTheme.title(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: WindowsAcrylicTheme.textPrimary,
                  ),
                ),
              ],
            ),

            // Draggable spacer in middle
            const Expanded(
              child: SizedBox(height: 24),
            ),

            // Right: Action buttons (Sync, Refresh, Close)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSync != null)
                  isSyncing
                      ? Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                WindowsAcrylicTheme.primary,
                              ),
                            ),
                          ),
                        )
                      : GlassIconButton(
                          icon: Icons.cloud_sync_outlined,
                          tooltip: 'Sync with backend',
                          size: 24,
                          iconSize: 14,
                          onTap: onSync,
                        ),
                if (onRefresh != null) ...[
                  const SizedBox(width: 2),
                  GlassIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh attendance',
                    size: 24,
                    iconSize: 14,
                    onTap: onRefresh,
                  ),
                ],
                const SizedBox(width: 2),
                GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  isClose: true,
                  size: 24,
                  iconSize: 14,
                  onTap: onClose ?? () => WindowService.closeWindow(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
