import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/app_usage_service.dart';
import '../../models/app_restriction.dart';
import '../../theme/app_theme.dart';

/// Page for discovering, selecting, and configuring apps for conscious usage control.
class AppSelectionPage extends StatefulWidget {
  final StorageService storage;

  const AppSelectionPage({super.key, required this.storage});

  @override
  State<AppSelectionPage> createState() => _AppSelectionPageState();
}

class _AppSelectionPageState extends State<AppSelectionPage> {
  List<InstalledAppInfo> _installedApps = [];
  bool _loading = true;
  String _searchQuery = '';
  int _filterIndex = 0; // 0: All, 1: Controlled, 2: Uncontrolled
  bool _hasUsage = true;
  bool _hasOverlay = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      final u = await AppUsageService.hasUsageStatsPermission();
      final o = await AppUsageService.hasOverlayPermission();
      if (mounted) {
        setState(() {
          _hasUsage = u;
          _hasOverlay = o;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _loading = true);
    if (Platform.isAndroid) {
      final apps = await AppUsageService.getInstalledApps();
      apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
      if (mounted) {
        setState(() {
          _installedApps = apps;
          _loading = false;
        });
      }
    } else {
      // Mock / fallback for non-Android platforms
      if (mounted) {
        setState(() {
          _installedApps = [
            const InstalledAppInfo(packageName: 'com.instagram.android', appName: 'Instagram'),
            const InstalledAppInfo(packageName: 'com.google.android.youtube', appName: 'YouTube'),
            const InstalledAppInfo(packageName: 'com.zhiliaoapp.musically', appName: 'TikTok'),
            const InstalledAppInfo(packageName: 'com.twitter.android', appName: 'X (Twitter)'),
            const InstalledAppInfo(packageName: 'com.reddit.frontpage', appName: 'Reddit'),
            const InstalledAppInfo(packageName: 'com.whatsapp', appName: 'WhatsApp'),
          ];
          _loading = false;
        });
      }
    }
  }

  List<InstalledAppInfo> get _filteredApps {
    return _installedApps.where((app) {
      final matchesSearch = _searchQuery.isEmpty ||
          app.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      final isControlled = widget.storage.isPackageControlled(app.packageName);
      if (_filterIndex == 1) return isControlled;
      if (_filterIndex == 2) return !isControlled;
      return true;
    }).toList();
  }

  AppRestriction? _getRestriction(String packageName) {
    try {
      return widget.storage.appRestrictions.firstWhere((r) => r.packageId == packageName);
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncRestrictionsToPlatform() async {
    final controlled = widget.storage.appRestrictions
        .where((r) => r.enabled)
        .map((r) => r.packageId)
        .toList();
    final strict = widget.storage.appRestrictions
        .where((r) => r.enabled && r.mode == UsageMode.strict)
        .map((r) => r.packageId)
        .toList();
    final limits = <String, int>{};
    for (final r in widget.storage.appRestrictions) {
      if (r.enabled) {
        limits[r.packageId] = r.dailyLimitMinutes;
      }
    }

    await AppUsageService.syncRestrictions(
      controlledPackages: controlled,
      strictPackages: strict,
    );
    await AppUsageService.updateDailyLimits(limits);
  }

  void _configureApp(InstalledAppInfo app) {
    final existing = _getRestriction(app.packageName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AppConfigSheet(
        app: app,
        initialRestriction: existing,
        onSave: (restriction) async {
          await widget.storage.saveAppRestriction(restriction);
          await _syncRestrictionsToPlatform();
          if (mounted) setState(() {});

          if (Platform.isAndroid) {
            final u = await AppUsageService.hasUsageStatsPermission();
            final o = await AppUsageService.hasOverlayPermission();
            if ((!u || !o) && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.warningAmber,
                  duration: const Duration(seconds: 4),
                  content: Text(
                    !u
                        ? 'Notice: Grant Usage Access so LNote can detect when ${restriction.appName} is opened.'
                        : 'Notice: Grant "Display Over Other Apps" so the restriction screen appears over ${restriction.appName}.',
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  action: SnackBarAction(
                    label: 'Grant',
                    textColor: Colors.black,
                    onPressed: () {
                      if (!u) {
                        AppUsageService.requestUsageStatsPermission();
                      } else {
                        AppUsageService.requestOverlayPermission();
                      }
                    },
                  ),
                ),
              );
            }
          }
        },
        onRemove: () async {
          await widget.storage.removeAppRestriction(app.packageName);
          await _syncRestrictionsToPlatform();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controlledCount = widget.storage.appRestrictions.where((r) => r.enabled).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controlled Apps'),
        actions: [
          IconButton(
            tooltip: 'Refresh apps list',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadInstalledApps,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ─── Search & Quick Filter ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search installed apps...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(40)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(40)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // ─── Permission Notice Banner ───
          if (Platform.isAndroid && (!_hasUsage || !_hasOverlay))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningAmber.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      !_hasUsage
                          ? 'Usage Access is required to detect when restricted apps open.'
                          : 'Display Over Other Apps permission is required to show the blocker screen.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withAlpha(200),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (!_hasUsage) {
                        await AppUsageService.requestUsageStatsPermission();
                      } else {
                        await AppUsageService.requestOverlayPermission();
                      }
                      _checkPermissions();
                    },
                    child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // ─── Filter Tabs (Scrollable to prevent any screen overflow) ───
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('All (${_installedApps.length})', 0),
                const SizedBox(width: 8),
                _buildFilterChip('Controlled ($controlledCount)', 1),
                const SizedBox(width: 8),
                _buildFilterChip('Not Controlled', 2),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ─── Apps List ───
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.apps_outlined, size: 48, color: theme.colorScheme.onSurface.withAlpha(100)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? 'No applications match your search' : 'No applications found',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final restriction = _getRestriction(app.packageName);
                          final isControlled = restriction != null && restriction.enabled;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isControlled
                                  ? (restriction.mode == UsageMode.strict
                                      ? AppTheme.accentCyan.withAlpha(12)
                                      : AppTheme.accentTeal.withAlpha(12))
                                  : theme.colorScheme.surfaceContainerHighest.withAlpha(30),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isControlled
                                    ? (restriction.mode == UsageMode.strict
                                        ? AppTheme.accentCyan.withAlpha(60)
                                        : AppTheme.accentTeal.withAlpha(60))
                                    : theme.colorScheme.outline.withAlpha(25),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: _buildAppIcon(app),
                              title: Text(
                                app.appName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                              subtitle: isControlled
                                  ? Row(
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 4, right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: restriction.mode == UsageMode.strict
                                                ? AppTheme.accentCyan.withAlpha(30)
                                                : AppTheme.accentTeal.withAlpha(30),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            restriction.mode.displayName,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: restriction.mode == UsageMode.strict
                                                  ? AppTheme.accentCyan
                                                  : AppTheme.accentTeal,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Limit: ${restriction.dailyLimitMinutes}m/day',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface.withAlpha(150),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      app.packageName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: theme.colorScheme.onSurface.withAlpha(110),
                                      ),
                                    ),
                              trailing: IconButton(
                                icon: Icon(
                                  isControlled ? Icons.tune_rounded : Icons.add_circle_outline_rounded,
                                  color: isControlled ? AppTheme.accentTeal : theme.colorScheme.onSurface.withAlpha(120),
                                ),
                                onPressed: () => _configureApp(app),
                              ),
                              onTap: () => _configureApp(app),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _filterIndex == index;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterIndex = index),
      selectedColor: AppTheme.accentTeal.withAlpha(40),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.accentTeal : theme.colorScheme.onSurface.withAlpha(180),
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.accentTeal : theme.colorScheme.outline.withAlpha(40),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildAppIcon(InstalledAppInfo app) {
    if (app.iconBytes != null && app.iconBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          app.iconBytes!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _defaultAppIcon(),
        ),
      );
    }
    return _defaultAppIcon();
  }

  Widget _defaultAppIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.accentTeal.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.apps_rounded, color: AppTheme.accentTeal, size: 22),
    );
  }
}

/// Bottom sheet dialog to configure restrictions for an app.
class _AppConfigSheet extends StatefulWidget {
  final InstalledAppInfo app;
  final AppRestriction? initialRestriction;
  final ValueChanged<AppRestriction> onSave;
  final VoidCallback onRemove;

  const _AppConfigSheet({
    required this.app,
    this.initialRestriction,
    required this.onSave,
    required this.onRemove,
  });

  @override
  State<_AppConfigSheet> createState() => _AppConfigSheetState();
}

class _AppConfigSheetState extends State<_AppConfigSheet> {
  late bool _enabled;
  late UsageMode _mode;
  late int _dailyLimitMinutes;
  late List<int> _allowedPresets;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRestriction;
    _enabled = r?.enabled ?? true;
    _mode = r?.mode ?? UsageMode.normal;
    _dailyLimitMinutes = r?.dailyLimitMinutes ?? 30;
    _allowedPresets = r != null ? List<int>.from(r.allowedPresets) : [1, 2, 3, 5, 10, 15, 30];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // App Header
            Row(
              children: [
                if (widget.app.iconBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(widget.app.iconBytes!, width: 48, height: 48, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.apps_rounded, color: AppTheme.accentTeal, size: 24),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.app.appName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.app.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(120)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  activeThumbColor: AppTheme.accentTeal,
                  onChanged: (val) => setState(() => _enabled = val),
                ),
              ],
            ),
            const Divider(height: 28),

            // ─── Mode Selection ───
            Text(
              'CONTROL MODE',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
            const SizedBox(height: 10),
            _buildModeOption(
              mode: UsageMode.normal,
              title: 'Normal Mode',
              subtitle: 'Use freely until daily limit is reached. Then asks for a conscious reason and duration.',
              icon: Icons.timelapse_rounded,
              color: AppTheme.accentTeal,
            ),
            const SizedBox(height: 8),
            _buildModeOption(
              mode: UsageMode.strict,
              title: 'Strict Mode',
              subtitle: 'Requires a conscious reason & time limit EVERY time you attempt to open the app.',
              icon: Icons.lock_clock_rounded,
              color: AppTheme.accentCyan,
            ),
            if (_mode == UsageMode.strict) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentCyan.withAlpha(40)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.accentCyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Platform Architecture Notice: Android\'s UsageStatsManager detects apps as usage events occur rather than pre-locking at the OS level. The conscious reflection screen appears upon detection.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withAlpha(160),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ─── Daily Limit ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DAILY USAGE LIMIT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
                Text(
                  _dailyLimitMinutes == 0 ? '0 min (Blocked immediately)' : '$_dailyLimitMinutes min',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [0, 5, 10, 15, 30, 45, 60, 90, 120].map((mins) {
                final isSel = _dailyLimitMinutes == mins;
                return ChoiceChip(
                  label: Text(mins == 0 ? '0m (Block now)' : '$mins min'),
                  selected: isSel,
                  onSelected: (_) => setState(() => _dailyLimitMinutes = mins),
                  selectedColor: AppTheme.accentTeal.withAlpha(35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ─── Temporary Access Presets ───
            Text(
              'ALLOWED EXTRA TIME PRESETS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 2, 3, 5, 10, 15, 20, 30].map((preset) {
                final isSelected = _allowedPresets.contains(preset);
                return FilterChip(
                  label: Text('$preset min'),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _allowedPresets.add(preset);
                        _allowedPresets.sort();
                      } else if (_allowedPresets.length > 1) {
                        _allowedPresets.remove(preset);
                      }
                    });
                  },
                  selectedColor: AppTheme.accentTeal.withAlpha(35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ─── Actions ───
            Row(
              children: [
                if (widget.initialRestriction != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: BorderSide(color: AppTheme.errorRed.withAlpha(80)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        widget.onRemove();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Remove Control'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final updated = AppRestriction(
                        packageId: widget.app.packageName,
                        appName: widget.app.appName,
                        enabled: _enabled,
                        mode: _mode,
                        dailyLimitMinutes: _dailyLimitMinutes,
                        allowedPresets: _allowedPresets,
                        createdAt: widget.initialRestriction?.createdAt ?? DateTime.now().toIso8601String(),
                        updatedAt: DateTime.now().toIso8601String(),
                      );
                      widget.onSave(updated);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save Restriction', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required UsageMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).colorScheme.outline.withAlpha(40),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withAlpha(120), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : null),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface.withAlpha(140)),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Theme.of(context).colorScheme.outline.withAlpha(100),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
