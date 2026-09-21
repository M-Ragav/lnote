import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'pages/profile_setup_page.dart';
import 'pages/main_shell.dart';
import 'pages/desktop_widget_view.dart';

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

  runApp(LNoteApp(
    storage: storage,
    isWidgetMode: args.contains('--widget'),
  ));
}

class LNoteApp extends StatefulWidget {
  final StorageService storage;
  final bool isWidgetMode;

  const LNoteApp({
    super.key,
    required this.storage,
    this.isWidgetMode = false,
  });

  @override
  State<LNoteApp> createState() => _LNoteAppState();
}

class _LNoteAppState extends State<LNoteApp> with WidgetsBindingObserver {
  Timer? _periodicSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.storage.addListener(_onUpdate);

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
    if (state == AppLifecycleState.resumed) {
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
    return MaterialApp(
      title: widget.isWidgetMode ? 'LNote Widget' : 'LNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: widget.storage.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: widget.isWidgetMode
          ? DesktopWidgetView(storage: widget.storage)
          : (widget.storage.hasProfile
              ? MainShell(storage: widget.storage)
              : ProfileSetupPage(storage: widget.storage)),
    );
  }
}
