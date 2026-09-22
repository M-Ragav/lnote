import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class DashboardCardWidget extends StatefulWidget {
  final StorageService storage;
  final bool compact;
  final bool isGlass;

  const DashboardCardWidget({
    super.key,
    required this.storage,
    this.compact = false,
    this.isGlass = false,
  });

  @override
  State<DashboardCardWidget> createState() => _DashboardCardWidgetState();
}

class _DashboardCardWidgetState extends State<DashboardCardWidget> {
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

  int _daysLived() {
    final profile = widget.storage.profile;
    if (profile == null) return widget.storage.attendanceDays.length;
    final today = DateUtils.dateOnly(DateTime.now());
    final birthday = DateUtils.dateOnly(profile.birthday);
    return today.difference(birthday).inDays + 1;
  }

  Future<void> _handleClockIn() async {
    if (widget.storage.hasActiveSession) return;
    final time = await widget.storage.clockIn();
    if (mounted) {
      final timeStr = TimeOfDay.fromDateTime(time).format(context);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.successGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text('IN recorded • $timeStr'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleClockOut() async {
    if (!widget.storage.hasActiveSession) return;
    final time = await widget.storage.clockOut();
    if (mounted) {
      final timeStr = TimeOfDay.fromDateTime(time).format(context);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.errorRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text('OUT recorded • $timeStr'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayData = widget.storage.today;
    final isActive = widget.storage.hasActiveSession;
    final sessionCount = todayData?.sessions.length ?? 0;
    final workTime = todayData?.formattedTotalDuration ?? '0m';
    final daysLived = _daysLived();

    return Container(
      padding: EdgeInsets.all(widget.compact ? 14 : 18),
      decoration: BoxDecoration(
        color: widget.isGlass
            ? (theme.brightness == Brightness.dark
                ? const Color(0x22FFFFFF)
                : const Color(0xCCFFFFFF))
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isGlass
              ? (theme.brightness == Brightness.dark
                  ? Colors.white.withAlpha(45)
                  : Colors.white.withAlpha(200))
              : theme.colorScheme.outline.withAlpha(77),
          width: widget.isGlass ? 1.0 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(widget.isGlass ? (theme.brightness == Brightness.dark ? 40 : 15) : 15),
            blurRadius: widget.isGlass ? 24 : 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB0100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/logopng.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LNote Dashboard',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withAlpha(128),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.successGreen.withAlpha(25)
                      : theme.colorScheme.onSurface.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.successGreen.withAlpha(80)
                        : theme.colorScheme.outline.withAlpha(60),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.successGreen : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'ACTIVE' : 'IDLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppTheme.successGreen : Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              // Days tracked / lived
              Expanded(
                child: _buildMetricTile(
                  theme,
                  label: 'Day Count',
                  value: NumberFormat('#,###').format(daysLived),
                  subtitle: 'Days lived',
                  icon: Icons.tag_rounded,
                  accentColor: AppTheme.accentTeal,
                ),
              ),
              const SizedBox(width: 10),
              // Sessions count
              Expanded(
                child: _buildMetricTile(
                  theme,
                  label: 'Today Sessions',
                  value: '$sessionCount',
                  subtitle: sessionCount == 1 ? '1 session' : '$sessionCount sessions',
                  icon: Icons.repeat_rounded,
                  accentColor: AppTheme.accentCyan,
                ),
              ),
              const SizedBox(width: 10),
              // Work duration
              Expanded(
                child: _buildMetricTile(
                  theme,
                  label: 'Work Duration',
                  value: workTime,
                  subtitle: 'Logged today',
                  icon: Icons.timer_outlined,
                  accentColor: AppTheme.warningAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Buttons: IN and OUT
          Row(
            children: [
              // IN Button
              Expanded(
                child: _buildActionButton(
                  theme,
                  label: 'IN',
                  subtitle: 'Start session',
                  icon: Icons.play_arrow_rounded,
                  gradient: AppTheme.startGradient,
                  isEnabled: !isActive,
                  onTap: _handleClockIn,
                ),
              ),
              const SizedBox(width: 12),
              // OUT Button
              Expanded(
                child: _buildActionButton(
                  theme,
                  label: 'OUT',
                  subtitle: 'End session',
                  icon: Icons.stop_rounded,
                  gradient: AppTheme.endGradient,
                  isEnabled: isActive,
                  onTap: _handleClockOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(50),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor.withAlpha(200)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: widget.compact ? 14 : 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 9,
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    ThemeData theme, {
    required String label,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: isEnabled ? gradient : null,
              color: isEnabled ? null : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: isEnabled
                  ? null
                  : Border.all(
                      color: theme.colorScheme.outline.withAlpha(60),
                      width: 0.5,
                    ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: gradient.colors.first.withAlpha(80),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? Colors.black.withAlpha(40)
                        : theme.colorScheme.onSurface.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isEnabled
                        ? Colors.white
                        : theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isEnabled
                            ? Colors.white
                            : theme.colorScheme.onSurface.withAlpha(140),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        color: isEnabled
                            ? Colors.white.withAlpha(200)
                            : theme.colorScheme.onSurface.withAlpha(90),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
