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
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
        color: Colors.transparent,
        child: Row(
          children: [
            // Left: Brand logo & Title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: WindowsAcrylicTheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'L',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: WindowsAcrylicTheme.title(
                    size: 12,
                    weight: FontWeight.w600,
                    color: WindowsAcrylicTheme.textPrimary,
                  ),
                ),
              ],
            ),

            // Draggable spacer in middle
            const Expanded(
              child: SizedBox(height: 28),
            ),

            // Right: Action buttons (Sync, Refresh, Close)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSync != null)
                  isSyncing
                      ? Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                WindowsAcrylicTheme.primary,
                              ),
                            ),
                          ),
                        )
                      : GlassIconButton(
                          icon: Icons.cloud_sync_outlined,
                          tooltip: 'Sync with backend',
                          onTap: onSync,
                        ),
                if (onRefresh != null) ...[
                  const SizedBox(width: 2),
                  GlassIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh attendance',
                    onTap: onRefresh,
                  ),
                ],
                const SizedBox(width: 2),
                GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  isClose: true,
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
