import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/window_service.dart';
import '../widgets/desktop/acrylic_surface.dart';
import '../widgets/desktop/widget_header.dart';
import '../widgets/desktop/desktop_dashboard_card.dart';
import '../widgets/desktop/windows_calendar_card.dart';
import '../widgets/desktop/empty_glassy_card.dart';

/// Windows 11 Translucent Glass Desktop Widget View (400x200 px)
class DesktopWidgetView extends StatefulWidget {
  final StorageService storage;
  final String initialMode; // 'dashboard', 'calendar', or 'empty'

  const DesktopWidgetView({
    super.key,
    required this.storage,
    this.initialMode = 'dashboard',
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
    final String title;
    if (_mode == 'calendar') {
      title = 'LNote • Calendar';
    } else if (_mode == 'empty' || _mode == 'glassy') {
      title = 'LNote • Glass';
    } else {
      title = 'LNote • Dashboard';
    }

    Widget content;
    if (_mode == 'calendar') {
      content = WindowsCalendarCard(
        storage: widget.storage,
        compact: true,
      );
    } else if (_mode == 'empty' || _mode == 'glassy') {
      content = const EmptyGlassyCard();
    } else {
      content = DesktopDashboardCard(
        storage: widget.storage,
        compact: true,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AcrylicSurface(
        child: Column(
          children: [
            // Minimal Windows 11 Draggable Header
            WidgetHeader(
              title: title,
              onSync: _handleSync,
              onRefresh: _handleRefresh,
              onClose: () => WindowService.closeWindow(),
              isSyncing: _isSyncing,
            ),

            // Content Area - expands to fill the 400x200 card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
