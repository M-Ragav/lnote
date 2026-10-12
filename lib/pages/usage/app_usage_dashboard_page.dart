import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/storage_service.dart';
import '../../services/app_usage_service.dart';
import '../../models/app_restriction.dart';
import '../../models/usage_reason.dart';
import '../../theme/app_theme.dart';
import 'app_selection_page.dart';
import 'usage_history_page.dart';
import 'permission_onboarding_page.dart';

/// Main dashboard for App Usage Control & Conscious Usage.
class AppUsageDashboardPage extends StatefulWidget {
  final StorageService storage;

  const AppUsageDashboardPage({super.key, required this.storage});

  @override
  State<AppUsageDashboardPage> createState() => _AppUsageDashboardPageState();
}

class _AppUsageDashboardPageState extends State<AppUsageDashboardPage> with WidgetsBindingObserver {
  Map<String, int> _todayUsage = {};
  bool _loadingUsage = true;
  bool _hasUsagePermission = false;
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.storage.addListener(_onUpdate);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.storage.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    if (!Platform.isAndroid) {
      setState(() => _loadingUsage = false);
      return;
    }
    _hasUsagePermission = await AppUsageService.hasUsageStatsPermission();
    _hasOverlayPermission = await AppUsageService.hasOverlayPermission();

    if (_hasUsagePermission) {
      _todayUsage = await AppUsageService.getDailyUsageStats(DateTime.now());
    }
    if (mounted) setState(() => _loadingUsage = false);
  }

  String _formatMs(int ms) {
    final minutes = ms ~/ 60000;
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h ${m}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restrictions = widget.storage.appRestrictions;
    final consciousStats = widget.storage.getTodayConsciousStats();
    final allPermissionsGranted = _hasUsagePermission && _hasOverlayPermission;

    // Top apps by usage
    final sortedUsage = _todayUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topApps = sortedUsage.take(5).toList();
    final totalMs = _todayUsage.values.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Usage Control'),
        actions: [
          IconButton(
            tooltip: 'Usage History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UsageHistoryPage(storage: widget.storage),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ─── Permission Banner ───
          if (Platform.isAndroid && !allPermissionsGranted) ...[
            _buildPermissionBanner(theme),
            const SizedBox(height: 16),
          ],

          // ─── Today's Screen Time ───
          _buildScreenTimeCard(theme, totalMs, topApps),
          const SizedBox(height: 16),

          // ─── Controlled Apps Summary ───
          _buildControlledAppsCard(theme, restrictions),
          const SizedBox(height: 16),

          // ─── Conscious Usage Stats ───
          _buildConsciousStatsCard(theme, consciousStats),
          const SizedBox(height: 16),

          // ─── Quick Actions ───
          _buildQuickActions(theme),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningAmber.withAlpha(25),
            AppTheme.warningAmber.withAlpha(10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warningAmber.withAlpha(60),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withAlpha(35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.warningAmber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !_hasUsagePermission
                          ? 'Enforcement Degraded: Usage Access Missing'
                          : 'Enforcement Degraded: Display Permission Needed',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningAmber,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !_hasUsagePermission
                          ? 'Usage Access is revoked. Screen time limits cannot be calculated until granted.'
                          : 'Overlay permission is needed for immediate prompt display over restricted apps.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(160),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPermissionRow(theme, 'Usage Access', _hasUsagePermission),
          const SizedBox(height: 4),
          _buildPermissionRow(theme, 'Display Over Apps', _hasOverlayPermission),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: AppTheme.warningAmber.withAlpha(100)),
              ),
              icon: const Icon(Icons.settings_rounded, size: 18, color: AppTheme.warningAmber),
              label: const Text(
                'Set Up Permissions',
                style: TextStyle(color: AppTheme.warningAmber, fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PermissionOnboardingPage(storage: widget.storage),
                  ),
                );
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(ThemeData theme, String label, bool granted) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: granted ? AppTheme.accentTeal : theme.colorScheme.onSurface.withAlpha(100),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: granted
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withAlpha(140),
            fontWeight: granted ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildScreenTimeCard(ThemeData theme, int totalMs, List<MapEntry<String, int>> topApps) {
    // Try to resolve app names from restrictions
    String resolveAppName(String packageId) {
      final restriction = widget.storage.getRestriction(packageId);
      if (restriction != null) return restriction.appName;
      // Shorten package name
      final parts = packageId.split('.');
      return parts.length > 1 ? parts.last : packageId;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(40),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(theme.brightness == Brightness.dark ? 40 : 10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.screen_lock_portrait_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Screen Time",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, MMM d').format(DateTime.now()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _loadingUsage ? '...' : _formatMs(totalMs),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentTeal,
                ),
              ),
            ],
          ),
          if (!_loadingUsage && topApps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(
              color: theme.colorScheme.outline.withAlpha(30),
              height: 1,
            ),
            const SizedBox(height: 12),
            Text(
              'Top Apps',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 8),
            ...topApps.map((entry) {
              final fraction = totalMs > 0 ? entry.value / totalMs : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        resolveAppName(entry.key),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.accentTeal.withAlpha(180),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: Text(
                        _formatMs(entry.value),
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (!_hasUsagePermission && Platform.isAndroid) ...[
            const SizedBox(height: 12),
            Text(
              'Grant Usage Access permission to see screen time data.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(130),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlledAppsCard(ThemeData theme, List<AppRestriction> restrictions) {
    final enabledCount = restrictions.where((r) => r.enabled).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(40),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(theme.brightness == Brightness.dark ? 40 : 10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Controlled Apps',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$enabledCount active',
                  style: const TextStyle(
                    color: AppTheme.accentTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (restrictions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.app_blocking_outlined,
                      size: 36,
                      color: theme.colorScheme.onSurface.withAlpha(80),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No apps under control yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(130),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Apps'),
                      onPressed: () => _openAppSelection(),
                    ),
                  ],
                ),
              ),
            )
          else
            ...restrictions.take(4).map((r) => _buildControlledAppTile(theme, r)),
          if (restrictions.length > 4) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => _openAppSelection(),
                child: Text(
                  'View all ${restrictions.length} apps',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlledAppTile(ThemeData theme, AppRestriction r) {
    final isStrict = r.mode == UsageMode.strict;
    final modeColor = isStrict ? const Color(0xFFEF4444) : AppTheme.accentTeal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: modeColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isStrict ? Icons.lock_rounded : Icons.timer_outlined,
                color: modeColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.appName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${r.mode.displayName} • ${r.dailyLimitMinutes}min/day',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: modeColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: r.enabled ? AppTheme.accentTeal : theme.colorScheme.outline.withAlpha(60),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsciousStatsCard(ThemeData theme, Map<String, dynamic> stats) {
    final totalRequests = stats['totalRequests'] as int;
    final approved = stats['approved'] as int;
    final denied = stats['denied'] as int;
    final extraReq = stats['extraRequestedMinutes'] as int;
    final extraAppr = stats['extraApprovedMinutes'] as int;
    final topCategory = stats['topCategory'] as ReasonCategory?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(40),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(theme.brightness == Brightness.dark ? 40 : 10),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 20, color: AppTheme.accentCyan),
              const SizedBox(width: 8),
              Text(
                'Conscious Usage Today',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStatChip(theme, '$totalRequests', 'requests', AppTheme.accentCyan),
              _buildStatChip(theme, '$approved', 'approved', AppTheme.accentTeal),
              _buildStatChip(theme, '$denied', 'denied', AppTheme.errorRed),
            ],
          ),
          if (totalRequests > 0) ...[
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outline.withAlpha(25), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(theme, 'Extra requested', '${extraReq}m'),
                ),
                Expanded(
                  child: _buildStatRow(theme, 'Extra used', '${extraAppr}m'),
                ),
              ],
            ),
            if (topCategory != null) ...[
              const SizedBox(height: 8),
              _buildStatRow(
                theme,
                'Top reason',
                '${topCategory.icon} ${topCategory.displayName}',
              ),
            ],
          ],
          if (totalRequests == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No conscious access requests today',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(ThemeData theme, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withAlpha(200),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(ThemeData theme, String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(130),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      children: [
        _buildActionTile(
          theme,
          icon: Icons.apps_rounded,
          iconColor: AppTheme.accentTeal,
          title: 'Manage Controlled Apps',
          subtitle: 'Add, remove or configure app restrictions',
          onTap: () => _openAppSelection(),
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          theme,
          icon: Icons.history_rounded,
          iconColor: AppTheme.accentCyan,
          title: 'Usage History',
          subtitle: 'View past access requests and reasons',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UsageHistoryPage(storage: widget.storage),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (Platform.isAndroid)
          _buildActionTile(
            theme,
            icon: Icons.shield_outlined,
            iconColor: AppTheme.warningAmber,
            title: 'Permissions & Setup',
            subtitle: 'Configure required system permissions',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PermissionOnboardingPage(storage: widget.storage),
                ),
              );
              _loadData();
            },
          ),
      ],
    );
  }

  Widget _buildActionTile(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(25),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(140),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withAlpha(80), size: 20),
          ],
        ),
      ),
    );
  }

  void _openAppSelection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppSelectionPage(storage: widget.storage),
      ),
    );
  }
}
