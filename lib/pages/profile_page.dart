import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../widgets/backend_config_sheet.dart';
import 'desktop_widget_view.dart';

class ProfilePage extends StatefulWidget {
  final StorageService storage;

  const ProfilePage({super.key, required this.storage});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    widget.storage.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.storage.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.storage.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Avatar + Name card
          _buildProfileHeader(theme, profile),
          const SizedBox(height: 20),

          // ─── Personal ─────────────────────────────
          _sectionLabel(theme, 'PERSONAL'),
          const SizedBox(height: 8),

          // Edit profile
          _buildTapTile(
            theme,
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Change name or birthday',
            onTap: () => _showEditSheet(context),
          ),
          const SizedBox(height: 20),

          // ─── Appearance & Preferences ──────────────
          _sectionLabel(theme, 'PREFERENCES'),
          const SizedBox(height: 8),

          // Theme toggle
          _buildSwitchTile(
            theme,
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Toggle dark / light theme',
            value: widget.storage.isDarkMode,
            onChanged: (val) => widget.storage.setDarkMode(val),
          ),
          const SizedBox(height: 8),

          // Notifications
          _buildSwitchTile(
            theme,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'IN alert + OUT reminder after 50 min',
            value: widget.storage.notificationsEnabled,
            onChanged: (val) => widget.storage.setNotificationsEnabled(val),
          ),
          const SizedBox(height: 8),

          // Daily target
          _buildTargetTile(theme),
          const SizedBox(height: 20),

          // ─── Cloud Sync ──────────────────────────────
          _sectionLabel(theme, 'CLOUD SYNC'),
          const SizedBox(height: 8),

          // Backend Server configuration
          _buildBackendServerTile(theme),
          const SizedBox(height: 8),

          // Auto-sync toggle
          _buildSwitchTile(
            theme,
            icon: Icons.sync_rounded,
            title: 'Automatic Sync',
            subtitle: 'Sync on app open, session updates & every 30s',
            value: widget.storage.autoSyncEnabled,
            onChanged: (val) => widget.storage.setAutoSyncEnabled(val),
          ),
          const SizedBox(height: 8),

          // Sync Now button
          _buildTapTile(
            theme,
            icon: Icons.refresh_rounded,
            title: 'Sync Now',
            subtitle: widget.storage.lastSyncTime != null
                ? 'Last synced ${_formatTimeAgo(widget.storage.lastSyncTime!)}'
                : (widget.storage.isBackendConfigured
                    ? 'Tap to sync all sessions with backend'
                    : 'Set backend link first'),
            iconColor: AppTheme.accentTeal,
            onTap: () {
              if (widget.storage.isBackendConfigured) {
                _triggerManualSync(context);
              } else {
                BackendConfigSheet.show(context, widget.storage);
              }
            },
          ),
          const SizedBox(height: 20),

          // ─── Data ──────────────────────────────────
          _sectionLabel(theme, 'DATA'),
          const SizedBox(height: 8),

          // Stats
          _buildTapTile(
            theme,
            icon: Icons.bar_chart_rounded,
            title: 'Attendance Statistics',
            subtitle: 'View your overall stats',
            onTap: () => _showStats(context),
          ),
          const SizedBox(height: 8),

          // Export
          _buildTapTile(
            theme,
            icon: Icons.file_upload_outlined,
            title: 'Export Data',
            subtitle: 'Export all data as JSON',
            onTap: () => _exportData(context),
          ),
          const SizedBox(height: 8),

          // Import
          _buildTapTile(
            theme,
            icon: Icons.file_download_outlined,
            title: 'Import Data',
            subtitle: 'Coming soon',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import will be available soon')),
              );
            },
          ),
          const SizedBox(height: 8),

          // Clear data
          _buildTapTile(
            theme,
            icon: Icons.delete_outline_rounded,
            title: 'Clear Attendance Data',
            subtitle: 'Remove all session records',
            iconColor: AppTheme.errorRed,
            onTap: () => _confirmClear(context),
          ),
          const SizedBox(height: 20),

          // ─── Security & Info ───────────────────────
          _sectionLabel(theme, 'SECURITY & INFO'),
          const SizedBox(height: 8),

          // App lock (stub)
          _buildTapTile(
            theme,
            icon: Icons.lock_outline_rounded,
            title: 'App Lock',
            subtitle: 'Coming soon',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'App Lock will be available in a future update')),
              );
            },
          ),
          // Desktop Widget
          _buildTapTile(
            theme,
            icon: Icons.widgets_outlined,
            title: 'Desktop Widget',
            subtitle: 'Preview desktop dashboard & calendar widget',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Desktop Widget Preview'),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    body: DesktopWidgetView(storage: widget.storage),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // About
          _buildTapTile(
            theme,
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'LNote v1.0.0',
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withAlpha(102),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, UserProfile? profile) {
    if (profile == null) return const SizedBox.shrink();

    final initials = profile.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentTeal.withAlpha(15),
            AppTheme.accentCyan.withAlpha(8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentTeal.withAlpha(40),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentTeal.withAlpha(60),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            profile.name,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Birthday
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cake_outlined,
                  size: 14, color: AppTheme.accentTeal.withAlpha(179)),
              const SizedBox(width: 6),
              Text(
                DateFormat('d MMMM yyyy').format(profile.birthday),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(77),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.accentTeal.withAlpha(179)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.accentTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTile(ThemeData theme) {
    final hours = widget.storage.dailyTargetHours;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(77),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.track_changes_rounded,
                  size: 22, color: AppTheme.accentTeal.withAlpha(179)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Work Target',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('${hours.round()} hours per day',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.accentTeal,
              inactiveTrackColor:
                  theme.colorScheme.onSurface.withAlpha(26),
              thumbColor: AppTheme.accentTeal,
              overlayColor: AppTheme.accentTeal.withAlpha(30),
              trackHeight: 4,
            ),
            child: Slider(
              min: 1,
              max: 16,
              divisions: 15,
              value: hours,
              label: '${hours.round()}h',
              onChanged: (val) => widget.storage.setDailyTargetHours(val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTapTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(77),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: iconColor ?? AppTheme.accentTeal.withAlpha(179)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withAlpha(77),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackendServerTile(ThemeData theme) {
    final isConfigured = widget.storage.isBackendConfigured;
    final status = widget.storage.syncStatus;

    Widget statusBadge;
    if (!isConfigured) {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Not Set',
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
      );
    } else if (status == SyncStatus.syncing) {
      statusBadge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentTeal),
          ),
          const SizedBox(width: 6),
          Text(
            'Syncing...',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.accentTeal,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else if (status == SyncStatus.error) {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withAlpha(30),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Offline',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.errorRed,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accentTeal.withAlpha(30),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppTheme.accentTeal,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Connected',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.accentTeal,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return _buildTapTile(
      theme,
      icon: Icons.cloud_sync_outlined,
      title: 'Backend Server',
      subtitle: isConfigured ? widget.storage.backendUrl! : 'Configure backend link',
      trailing: statusBadge,
      onTap: () => BackendConfigSheet.show(context, widget.storage),
    );
  }

  Future<void> _triggerManualSync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Syncing with backend...'),
        duration: Duration(seconds: 1),
      ),
    );

    final ok = await widget.storage.triggerSync();
    if (!mounted) return;

    if (ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('All data synced successfully!'),
          backgroundColor: AppTheme.accentTeal,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${widget.storage.lastSyncError ?? "Check backend URL"}'),
          backgroundColor: AppTheme.errorRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  // ─── Dialogs & Sheets ─────────────────────────────────────

  Future<void> _exportData(BuildContext context) async {
    try {
      final jsonStr = widget.storage.exportData();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/lnote_export_$timestamp.json');
      await file.writeAsString(jsonStr);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showStats(BuildContext context) {
    final theme = Theme.of(context);
    final days = widget.storage.attendanceDays;
    final totalDays = days.length;
    final totalSessions =
        days.fold<int>(0, (sum, d) => sum + d.sessions.length);
    final totalMinutes =
        days.fold<int>(0, (sum, d) => sum + d.totalDuration.inMinutes);
    final totalHours = totalMinutes ~/ 60;
    final remainMinutes = totalMinutes % 60;
    final avgMinutes = totalDays > 0 ? totalMinutes ~/ totalDays : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(51),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Attendance Statistics',
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 20),
            _statRow(theme, 'Total Days Tracked', '$totalDays'),
            _statRow(theme, 'Total Sessions', '$totalSessions'),
            _statRow(
                theme, 'Total Work Time', '${totalHours}h ${remainMinutes}m'),
            _statRow(theme, 'Average per Day',
                '${avgMinutes ~/ 60}h ${avgMinutes % 60}m'),
          ],
        ),
      ),
    );
  }

  Widget _statRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.accentTeal,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Data', style: theme.textTheme.headlineMedium),
        content: Text(
          'This will permanently delete all your attendance records. This cannot be undone.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          TextButton(
            onPressed: () {
              widget.storage.clearAttendance();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Attendance data cleared')),
              );
            },
            child:
                Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(51),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFB0100),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.outline.withAlpha(50),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFB0100).withAlpha(60),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/logopng.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 16),
            Text('LNote', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Version 1.0.0', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text(
              'Your personal work session tracker.\nTrack your daily work hours with ease.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.storage.profile;
    if (profile == null) return;

    final nameController = TextEditingController(text: profile.name);
    DateTime selectedBirthday = profile.birthday;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(51),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Edit Profile', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 20),

              // Name
              Text(
                'NAME',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: theme.textTheme.titleMedium,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: theme.colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: theme.colorScheme.outline.withAlpha(128)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppTheme.accentTeal, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Birthday
              Text(
                'BIRTHDAY',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedBirthday,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme:
                              Theme.of(context).colorScheme.copyWith(
                                    primary: AppTheme.accentTeal,
                                  ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setSheetState(() => selectedBirthday = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(128),
                    ),
                  ),
                  child: Text(
                    DateFormat('d MMMM yyyy').format(selectedBirthday),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isNotEmpty) {
                        await widget.storage.saveProfile(
                          UserProfile(
                              name: name, birthday: selectedBirthday),
                        );
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
