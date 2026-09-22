import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/window_service.dart';
import '../widgets/desktop/acrylic_surface.dart';
import '../widgets/desktop/widget_header.dart';
import '../widgets/desktop/windows_segmented_control.dart';
import '../widgets/desktop/desktop_dashboard_card.dart';
import '../widgets/desktop/windows_calendar_card.dart';

/// Windows 11 Light Acrylic Desktop Widget View
class DesktopWidgetView extends StatefulWidget {
  final StorageService storage;
  final String initialMode; // 'all', 'dashboard', 'calendar'

  const DesktopWidgetView({
    super.key,
    required this.storage,
    this.initialMode = 'all',
  });

  @override
  State<DesktopWidgetView> createState() => _DesktopWidgetViewState();
}

class _DesktopWidgetViewState extends State<DesktopWidgetView> {
  late String _mode;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    widget.storage.addListener(_onStorageUpdate);
  }

  @override
  void dispose() {
    widget.storage.removeListener(_onStorageUpdate);
    super.dispose();
  }

  void _onStorageUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await widget.storage.triggerSync();
    } catch (_) {
      // Ignored if backend not reachable
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleRefresh() async {
    await widget.storage.reloadAttendance();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showSegmentSwitcher = widget.initialMode == 'all';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AcrylicSurface(
        child: Column(
          children: [
            // Minimal Windows 11 Draggable Header
            WidgetHeader(
              title: _getHeaderTitle(),
              onSync: _handleSync,
              onRefresh: _handleRefresh,
              onClose: () => WindowService.closeWindow(),
              isSyncing: _isSyncing,
            ),

            // Segmented Control (shown in 'all' multi-mode view)
            if (showSegmentSwitcher) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WindowsSegmentedControl(
                      selected: _mode,
                      onChanged: (newMode) => setState(() => _mode = newMode),
                      items: const [
                        WindowsSegmentItem(value: 'all', label: 'All'),
                        WindowsSegmentItem(value: 'dashboard', label: 'Dashboard'),
                        WindowsSegmentItem(value: 'calendar', label: 'Calendar'),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_mode == 'all' || _mode == 'dashboard') ...[
                      DesktopDashboardCard(
                        storage: widget.storage,
                        compact: _mode == 'all',
                      ),
                    ],
                    if (_mode == 'all') const SizedBox(height: 10),
                    if (_mode == 'all' || _mode == 'calendar') ...[
                      WindowsCalendarCard(
                        storage: widget.storage,
                        compact: _mode == 'all',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_mode) {
      case 'dashboard':
        return 'LNote • Dashboard';
      case 'calendar':
        return 'LNote • Calendar';
      default:
        return 'LNote';
    }
  }
}
