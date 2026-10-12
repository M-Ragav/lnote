import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'services/food_prep_service.dart';
import 'services/app_usage_service.dart';
import 'models/app_restriction.dart';
import 'widgets/food_prep_dialog.dart';
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

  if (Platform.isAndroid && storage.appRestrictions.isNotEmpty) {
    try {
      final controlled = storage.appRestrictions
          .where((r) => r.enabled)
          .map((r) => r.packageId)
          .toList();
      final strict = storage.appRestrictions
          .where((r) => r.enabled && r.mode == UsageMode.strict)
          .map((r) => r.packageId)
          .toList();
      final limits = <String, int>{};
      for (final r in storage.appRestrictions) {
        if (r.enabled) {
          limits[r.packageId] = r.dailyLimitMinutes;
        }
      }
      AppUsageService.syncRestrictions(
        controlledPackages: controlled,
        strictPackages: strict,
      );
      AppUsageService.updateDailyLimits(limits);
    } catch (e) {
      debugPrint('Startup syncRestrictions error: $e');
    }
  }

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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _periodicSyncTimer;
  bool _isUnlocked = false;
  bool _isFoodPrepDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.storage.addListener(_onUpdate);

    _isUnlocked = !widget.storage.isAppLockEnabled;

    // Periodic sync & food prep check every 30 seconds while app is running
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.storage.isBackendConfigured && widget.storage.autoSyncEnabled) {
        widget.storage.triggerSync();
      }
      _checkFoodPrepTrigger();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFoodPrepTrigger();
    });
  }

  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.storage.removeListener(_onUpdate);
    super.dispose();
  }

  void _checkFoodPrepTrigger() {
    if (widget.widgetMode != null) return;
    if (_isFoodPrepDialogOpen) return;
    if (widget.storage.shouldTriggerFoodPrepNow()) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        _isFoodPrepDialogOpen = true;
        FoodPrepDialog.show(context, widget.storage).then((_) {
          _isFoodPrepDialogOpen = false;
        });
      }
      if (Platform.isAndroid) {
        FoodPrepService.showNativeFloatingWindow(widget.storage.getTomorrowFoods());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (widget.storage.isAppLockEnabled) {
        setState(() => _isUnlocked = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reopened or brought to foreground: immediately sync latest updates & check food prep
      if (widget.storage.isBackendConfigured && widget.storage.autoSyncEnabled) {
        widget.storage.triggerSync();
      }
      _checkFoodPrepTrigger();
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
      navigatorKey: _navigatorKey,
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
