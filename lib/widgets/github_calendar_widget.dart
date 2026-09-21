import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../models/attendance_day.dart';

class GitHubCalendarWidget extends StatelessWidget {
  final StorageService storage;
  final int weeksToShow;
  final bool compact;

  const GitHubCalendarWidget({
    super.key,
    required this.storage,
    this.weeksToShow = 16,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate start date: (weeksToShow) weeks ago, aligned to Monday
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    // Find current week's Monday (1 = Mon, 7 = Sun)
    final currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    final startDate = currentWeekMonday.subtract(Duration(days: (weeksToShow - 1) * 7));

    // Map existing days by date string "yyyy-MM-dd"
    final Map<String, AttendanceDay> dayMap = {};
    for (final day in storage.attendanceDays) {
      dayMap[day.date] = day;
    }

    // Generate grid data: 7 rows (Mon-Sun), weeksToShow columns
    final List<List<DateTime>> weeks = [];
    int totalLoggedMinutes = 0;
    int activeDaysCount = 0;

    for (int w = 0; w < weeksToShow; w++) {
      final List<DateTime> week = [];
      for (int d = 0; d < 7; d++) {
        final date = startDate.add(Duration(days: w * 7 + d));
        week.add(date);

        if (!date.isAfter(today)) {
          final dateStr = _dateStr(date);
          final attendance = dayMap[dateStr];
          if (attendance != null && attendance.totalDuration.inMinutes > 0) {
            totalLoggedMinutes += attendance.totalDuration.inMinutes;
            activeDaysCount++;
          }
        }
      }
      weeks.add(week);
    }

    final totalHours = totalLoggedMinutes ~/ 60;
    final totalMins = totalLoggedMinutes % 60;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(77),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: AppTheme.accentTeal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Work Activity',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Text(
                '${totalHours}h ${totalMins}m logged',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),

          // Calendar Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day of week labels (M, W, F)
                if (!compact) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _dayLabel(theme, 'M'),
                        const SizedBox(height: 12),
                        _dayLabel(theme, 'W'),
                        const SizedBox(height: 12),
                        _dayLabel(theme, 'F'),
                      ],
                    ),
                  ),
                ],

                // Grid columns (weeks)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month labels
                    _buildMonthHeaders(theme, weeks),
                    const SizedBox(height: 4),

                    // Days grid
                    Row(
                      children: weeks.map((week) {
                        return Column(
                          children: week.map((date) {
                            final isFuture = date.isAfter(today);
                            final dateStr = _dateStr(date);
                            final attendance = isFuture ? null : dayMap[dateStr];
                            return _buildCell(
                              context,
                              date: date,
                              attendance: attendance,
                              isFuture: isFuture,
                              isDark: isDark,
                              cellSize: compact ? 10.0 : 13.0,
                              spacing: compact ? 2.0 : 3.0,
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 12),

          // Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$activeDaysCount active days',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withAlpha(128),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Less',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ...List.generate(5, (level) {
                    return Container(
                      width: compact ? 8 : 10,
                      height: compact ? 8 : 10,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: _getColorForLevel(level, isDark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                  Text(
                    'More',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayLabel(ThemeData theme, String text) {
    return SizedBox(
      height: 12,
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 9,
          color: theme.colorScheme.onSurface.withAlpha(100),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMonthHeaders(ThemeData theme, List<List<DateTime>> weeks) {
    final List<Widget> headers = [];
    String? lastMonth;

    final cellTotalWidth = compact ? 12.0 : 16.0;

    for (int i = 0; i < weeks.length; i++) {
      final firstDayOfWeek = weeks[i][0];
      final monthName = DateFormat('MMM').format(firstDayOfWeek);

      if (monthName != lastMonth && firstDayOfWeek.day <= 7) {
        lastMonth = monthName;
        headers.add(
          SizedBox(
            width: cellTotalWidth * 3,
            child: Text(
              monthName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ),
        );
      } else if (lastMonth == null) {
        lastMonth = monthName;
        headers.add(
          SizedBox(
            width: cellTotalWidth * 2,
            child: Text(
              monthName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ),
        );
      }
    }

    return Row(children: headers);
  }

  Widget _buildCell(
    BuildContext context, {
    required DateTime date,
    required AttendanceDay? attendance,
    required bool isFuture,
    required bool isDark,
    required double cellSize,
    required double spacing,
  }) {
    final minutes = attendance?.totalDuration.inMinutes ?? 0;
    final level = _getLevel(minutes, isFuture);
    final color = _getColorForLevel(level, isDark);

    final dateFormatted = DateFormat('EEE, MMM d').format(date);
    final tooltipText = isFuture
        ? '$dateFormatted (Upcoming)'
        : minutes > 0
            ? '$dateFormatted: ${attendance!.formattedTotalDuration} (${attendance.sessions.length} sessions)'
            : '$dateFormatted: No work recorded';

    return Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 200),
      child: Container(
        width: cellSize,
        height: cellSize,
        margin: EdgeInsets.all(spacing / 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2.5),
          border: Border.all(
            color: isFuture
                ? Colors.transparent
                : level == 0
                    ? (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10))
                    : AppTheme.accentTeal.withAlpha(60),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  int _getLevel(int minutes, bool isFuture) {
    if (isFuture) return -1;
    if (minutes == 0) return 0;
    if (minutes < 120) return 1; // < 2 hours
    if (minutes < 240) return 2; // 2 - 4 hours
    if (minutes < 420) return 3; // 4 - 7 hours
    return 4; // 7+ hours
  }

  Color _getColorForLevel(int level, bool isDark) {
    if (level == -1) {
      // Future day
      return isDark ? const Color(0xFF141418) : const Color(0xFFF3F4F6);
    }
    switch (level) {
      case 0:
        // Grey
        return isDark ? const Color(0xFF222228) : const Color(0xFFE5E7EB);
      case 1:
        // Light teal tint
        return isDark
            ? AppTheme.accentTeal.withAlpha(70)
            : const Color(0xFF86EFAC);
      case 2:
        return isDark
            ? AppTheme.accentTeal.withAlpha(130)
            : const Color(0xFF4ADE80);
      case 3:
        return isDark
            ? AppTheme.accentTeal.withAlpha(190)
            : const Color(0xFF22C55E);
      case 4:
      default:
        return AppTheme.accentTeal;
    }
  }

  String _dateStr(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
