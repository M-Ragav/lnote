import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/session_button.dart';

class HomePage extends StatefulWidget {
  final StorageService storage;

  const HomePage({super.key, required this.storage});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  int _daysLived() {
    final profile = widget.storage.profile;
    if (profile == null) return 0;
    final today = DateUtils.dateOnly(DateTime.now());
    final birthday = DateUtils.dateOnly(profile.birthday);
    return today.difference(birthday).inDays + 1;
  }

  int _ageYears() {
    final profile = widget.storage.profile;
    if (profile == null) return 0;
    final now = DateTime.now();
    final bday = profile.birthday;
    int age = now.year - bday.year;
    if (now.month < bday.month ||
        (now.month == bday.month && now.day < bday.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.storage.profile;
    final todayData = widget.storage.today;
    final daysLived = _daysLived();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting with Logo
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${_greeting()}, ${profile?.name ?? ''} 👋',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB0100),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outline.withAlpha(50),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFB0100).withAlpha(40),
                          blurRadius: 10,
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
                ],
              ),
              const SizedBox(height: 28),

              // Hero day counter card
              _buildHeroCard(theme, daysLived),
              const SizedBox(height: 12),

              // Born / Today row
              _buildDateRow(theme),
              const SizedBox(height: 20),

              // Stats grid
              _buildStatsGrid(theme, todayData, daysLived),

              // Work progress (if daily target set)
              if (todayData != null) ...[
                const SizedBox(height: 16),
                _buildWorkProgress(theme, todayData),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: SessionButton(storage: widget.storage),
    );
  }

  Widget _buildHeroCard(ThemeData theme, int daysLived) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentTeal.withAlpha(20),
            AppTheme.accentCyan.withAlpha(10),
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
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.accentGradient.createShader(bounds),
            child: Text(
              NumberFormat('#,###').format(daysLived),
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontSize: 64,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Days you\'ve lived',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(ThemeData theme) {
    final profile = widget.storage.profile;
    if (profile == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _miniInfoCard(
            theme,
            'Born',
            DateFormat('d MMM yyyy').format(profile.birthday),
            Icons.cake_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniInfoCard(
            theme,
            'Today',
            DateFormat('d MMM yyyy').format(DateTime.now()),
            Icons.today_outlined,
          ),
        ),
      ],
    );
  }

  Widget _miniInfoCard(
      ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          Icon(icon, size: 18, color: AppTheme.accentTeal.withAlpha(179)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
      ThemeData theme, dynamic todayData, int daysLived) {
    final sessionCount = todayData?.sessions.length ?? 0;
    final workTime = todayData?.formattedTotalDuration ?? '0m';
    final lastActivity = _lastActivity(todayData);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(theme, 'Today', 'Day $daysLived',
                  Icons.tag_rounded, AppTheme.accentTeal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(theme, 'Age', '${_ageYears()} years',
                  Icons.person_outline_rounded, AppTheme.accentCyan),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(theme, 'Work time', workTime,
                  Icons.timer_outlined, AppTheme.warningAmber),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(theme, 'Sessions', '$sessionCount',
                  Icons.repeat_rounded, AppTheme.successGreen),
            ),
          ],
        ),
        if (lastActivity != null) ...[
          const SizedBox(height: 10),
          _lastActivityCard(theme, lastActivity),
        ],
      ],
    );
  }

  Widget _statCard(
      ThemeData theme, String label, String value, IconData icon, Color color) {
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
              Icon(icon, size: 16, color: color.withAlpha(179)),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String? _lastActivity(dynamic todayData) {
    if (todayData == null) return null;
    final sessions = todayData.sessions;
    if (sessions.isEmpty) return null;
    final last = sessions.last;
    if (last.outTime != null) {
      return 'OUT  ${DateFormat('h:mm a').format(last.outTime!)}';
    }
    return 'IN  ${DateFormat('h:mm a').format(last.inTime)}';
  }

  Widget _lastActivityCard(ThemeData theme, String activity) {
    final isIn = activity.startsWith('IN');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isIn ? AppTheme.successGreen : AppTheme.errorRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Last activity',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
          const Spacer(),
          Text(
            activity,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkProgress(ThemeData theme, dynamic todayData) {
    final totalMinutes = todayData.totalDuration.inMinutes;
    final targetMinutes = (widget.storage.dailyTargetHours * 60).round();
    final progress = targetMinutes > 0
        ? (totalMinutes / targetMinutes).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progress * 100).round();

    return Container(
      width: double.infinity,
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
              Icon(Icons.trending_up_rounded,
                  size: 16, color: AppTheme.accentTeal.withAlpha(179)),
              const SizedBox(width: 8),
              Text(
                'Today\'s Work',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
              ),
              const Spacer(),
              Text(
                '${todayData.formattedTotalDuration} / ${widget.storage.dailyTargetHours.round()}h',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.onSurface.withAlpha(26),
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$percent%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.accentTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
