import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/session_button.dart';
import '../widgets/food_prep_dialog.dart';
import 'control_page.dart';
import 'usage/app_usage_dashboard_page.dart';

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
      drawer: _buildDrawer(context, theme),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting with Drawer Trigger and Logo
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Builder(
                    builder: (scaffoldContext) => InkWell(
                      onTap: () => Scaffold.of(scaffoldContext).openDrawer(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withAlpha(35),
                          ),
                        ),
                        child: const Icon(Icons.menu_rounded, size: 24),
                      ),
                    ),
                  ),
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

  Widget _buildDrawer(BuildContext context, ThemeData theme) {
    final profile = widget.storage.profile;
    final skillsCount = widget.storage.skills.length;

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentTeal.withAlpha(30),
                    AppTheme.accentCyan.withAlpha(15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(35),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentTeal.withAlpha(80),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      profile?.name.isNotEmpty == true
                          ? profile!.name[0].toUpperCase()
                          : 'L',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profile?.name ?? 'User',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LNote Personal Workspace',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  // Skills Option (moved from bottom nav)
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.accentTeal.withAlpha(40),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Skills',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Mastery hours & learning tags',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$skillsCount',
                          style: const TextStyle(
                            color: AppTheme.accentTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop(); // close drawer
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SkillsPage(storage: widget.storage),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Food Preparation Checklist shortcut
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.checklist_rtl_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    title: const Text('Food Preparation'),
                    subtitle: Text(
                      'Tomorrow\'s food checklist',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      FoodPrepDialog.show(context, widget.storage);
                    },
                  ),
                  const SizedBox(height: 10),

                  // App Usage Control (Conscious usage & app limits)
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.accentCyan.withAlpha(40),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.screen_lock_portrait_rounded,
                          color: AppTheme.accentCyan,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'App Usage Control',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Conscious app usage & limits',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withAlpha(35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.storage.appRestrictions.where((r) => r.enabled).length}',
                          style: const TextStyle(
                            color: AppTheme.accentCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AppUsageDashboardPage(storage: widget.storage),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'LNote v1.0.1 • Focus & Health',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
