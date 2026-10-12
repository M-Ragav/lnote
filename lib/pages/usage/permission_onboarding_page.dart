import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/app_usage_service.dart';
import '../../theme/app_theme.dart';

/// Step-by-step onboarding & permission management page for App Usage Control.
class PermissionOnboardingPage extends StatefulWidget {
  final StorageService storage;

  const PermissionOnboardingPage({super.key, required this.storage});

  @override
  State<PermissionOnboardingPage> createState() => _PermissionOnboardingPageState();
}

class _PermissionOnboardingPageState extends State<PermissionOnboardingPage> with WidgetsBindingObserver {
  bool _hasUsage = false;
  bool _hasOverlay = false;
  bool _hasBattery = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _checking = true);
    if (!Platform.isAndroid) {
      setState(() {
        _hasUsage = true;
        _hasOverlay = true;
        _hasBattery = true;
        _checking = false;
      });
      return;
    }

    final usage = await AppUsageService.hasUsageStatsPermission();
    final overlay = await AppUsageService.hasOverlayPermission();
    final battery = await AppUsageService.isBatteryOptimizationIgnored();

    if (mounted) {
      setState(() {
        _hasUsage = usage;
        _hasOverlay = overlay;
        _hasBattery = battery;
        _checking = false;
      });
    }
  }

  bool get _allGranted => _hasUsage && _hasOverlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions & Setup'),
        actions: [
          if (_checking)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Recheck permissions',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _checkPermissions,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _allGranted ? const Color(0xFF10B981).withAlpha(30) : AppTheme.accentTeal.withAlpha(25),
                  theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _allGranted ? const Color(0xFF10B981).withAlpha(80) : AppTheme.accentTeal.withAlpha(50),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _allGranted ? const Color(0xFF10B981).withAlpha(40) : AppTheme.accentTeal.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _allGranted ? Icons.verified_rounded : Icons.shield_outlined,
                    color: _allGranted ? const Color(0xFF10B981) : AppTheme.accentTeal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _allGranted ? 'System Fully Configured' : 'Operating System Setup',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _allGranted
                            ? 'All 3 OS integrations are active. Intentional app usage is enforced.'
                            : 'To monitor usage and intercept controlled apps, grant the permissions below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'REQUIRED PERMISSIONS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
          ),
          const SizedBox(height: 12),

          // 1. Usage Access (UsageStatsManager)
          _buildPermissionStep(
            theme,
            stepNumber: 1,
            title: 'Usage Access',
            subtitle: 'Usage Access allows this app to calculate the time you spend in applications you select and determine when your usage limits have been reached.',
            isGranted: _hasUsage,
            icon: Icons.query_stats_rounded,
            onRequest: () async {
              await AppUsageService.requestUsageStatsPermission();
            },
          ),
          const SizedBox(height: 12),

          // 2. Overlay (System Alert Window)
          _buildPermissionStep(
            theme,
            stepNumber: 2,
            title: 'Display Over Other Apps',
            subtitle: 'Displays the conscious reflection prompt cleanly over restricted applications when limits are reached.',
            isGranted: _hasOverlay,
            icon: Icons.layers_rounded,
            onRequest: () async {
              await AppUsageService.requestOverlayPermission();
            },
          ),
          const SizedBox(height: 12),

          // 3. Battery Optimization Exemption (Background Reliability)
          _buildPermissionStep(
            theme,
            stepNumber: 3,
            title: 'Battery Optimization Exemption',
            subtitle: 'Prevents the Android OS and device task-killer from suspending background usage reconciliation.',
            isGranted: _hasBattery,
            icon: Icons.battery_charging_full_rounded,
            onRequest: () async {
              await AppUsageService.requestIgnoreBatteryOptimization();
            },
          ),
          const SizedBox(height: 28),

          // Privacy Assurance
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline.withAlpha(20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded, color: AppTheme.accentTeal, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '100% On-Device Privacy',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'LNote uses Android\'s legitimate UsageStatsManager API. '
                        'It does not inspect screen content, keystrokes, personal messages, or private data.',
                        style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withAlpha(140)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _allGranted ? const Color(0xFF10B981) : AppTheme.accentTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              _allGranted ? 'Done & Return to Dashboard' : 'Continue to Dashboard',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStep(
    ThemeData theme, {
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isGranted,
    required IconData icon,
    required VoidCallback onRequest,
  }) {
    final statusColor = isGranted ? const Color(0xFF10B981) : AppTheme.warningAmber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? statusColor.withAlpha(50) : theme.colorScheme.outline.withAlpha(30),
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
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    Text(
                      isGranted ? 'Permission active' : 'Action required',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
              ),
              Icon(
                isGranted ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: statusColor,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(140)),
          ),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentTeal,
                  side: BorderSide(color: AppTheme.accentTeal.withAlpha(80)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Open Settings & Enable', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                onPressed: onRequest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
