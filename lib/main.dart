import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'pages/profile_setup_page.dart';
import 'pages/main_shell.dart';
import 'pages/desktop_widget_view.dart';
import 'pages/lock_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize storage
  final storage = StorageService();
  await storage.init();

  String? widgetMode;
  for (final arg in args) {
    if (arg == '--widget=empty' || arg == '--widget=glassy' || arg == '--widget-empty') {
      widgetMode = 'empty';
      break;
    } else if (arg == '--widget=dashboard' || arg == '--widget-dashboard' || arg == '--widget' || arg == '--widget=all') {
      widgetMode = 'dashboard';
      break;
    } else if (arg == '--widget=calendar' || arg == '--widget-calendar') {
      widgetMode = 'calendar';
      break;
    }
  }

  runApp(LNoteApp(
    storage: storage,
    widgetMode: widgetMode,
  ));
}

class LNoteApp extends StatefulWidget {
  final StorageService storage;
  final String? widgetMode;

  const LNoteApp({
    super.key,
    required this.storage,
    this.widgetMode,
  });

  @override
  State<LNoteApp> createState() => _LNoteAppState();
}

class _LNoteAppState extends State<LNoteApp> with WidgetsBindingObserver {
  Timer? _periodicSyncTimer;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.storage.addListener(_onUpdate);

    _isUnlocked = !widget.storage.isAppLockEnabled;

    // Periodic sync every 30 seconds while app is running
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.storage.isBackendConfigured && widget.storage.autoSyncEnabled) {
        widget.storage.triggerSync();
      }
    });
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.storage.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (widget.storage.isAppLockEnabled) {
        setState(() => _isUnlocked = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reopened or brought to foreground: immediately sync latest updates
      if (widget.storage.isBackendConfigured && widget.storage.autoSyncEnabled) {
        widget.storage.triggerSync();
      }
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isWidget = widget.widgetMode != null;
    final widgetTitle = widget.widgetMode == 'calendar'
        ? 'LNote Calendar Widget'
        : 'LNote Dashboard Widget';

    return MaterialApp(
      title: isWidget ? widgetTitle : 'LNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: isWidget
          ? ThemeMode.light
          : (widget.storage.isDarkMode ? ThemeMode.dark : ThemeMode.light),
      home: isWidget
          ? DesktopWidgetView(
              storage: widget.storage,
              initialMode: widget.widgetMode!,
            )
          : (!widget.storage.hasProfile
              ? ProfileSetupPage(storage: widget.storage)
              : (widget.storage.isAppLockEnabled && !_isUnlocked
                  ? LockScreen(
                      storage: widget.storage,
                      onUnlocked: () => setState(() => _isUnlocked = true),
                    )
                  : MainShell(storage: widget.storage))),
    );
  }
}
