import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/attendance_day.dart';

class GitHubCalendarWidget extends StatelessWidget {
  final StorageService storage;
  final int weeksToShow;
  final bool compact;
  final bool isGlass;
  final bool showDayNumbers;

  const GitHubCalendarWidget({
    super.key,
    required this.storage,
    this.weeksToShow = 15,
    this.compact = false,
    this.isGlass = false,
    this.showDayNumbers = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate start date: (weeksToShow) weeks ago, aligned to Monday
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
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

    final cellWidth = compact ? 20.0 : 28.0;
    final cellHeight = compact ? 19.0 : 26.0;
    final cellSpacing = compact ? 3.0 : 4.5;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: isGlass
            ? (isDark ? const Color(0x22FFFFFF) : const Color(0xCCFFFFFF))
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGlass
              ? (isDark ? Colors.white.withAlpha(45) : Colors.white.withAlpha(200))
              : theme.colorScheme.outline.withAlpha(77),
          width: isGlass ? 1.0 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isGlass ? (isDark ? 40 : 15) : 15),
            blurRadius: isGlass ? 24 : 16,
            offset: const Offset(0, 6),
          ),
        ],
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: Color(0xFFFF5722),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Work Activity',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF5722).withAlpha(50),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${totalHours}h ${totalMins}m logged',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFF5722),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),

          // Calendar Grid with Month Headers and Right-aligned Day Labels (Image 1 Style)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grid columns (weeks)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month labels (e.g. Jun 2026, Jul, Aug, Sept)
                    _buildMonthHeaders(theme, weeks, cellWidth + cellSpacing),
                    const SizedBox(height: 6),

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
                              cellWidth: cellWidth,
                              cellHeight: cellHeight,
                              spacing: cellSpacing,
                              showNumber: showDayNumbers,
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Day of week labels on the RIGHT (Mon, Tue, Wed, Thu, Fri, Sat, Sun) as in Image 1
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 22),
                  child: Column(
                    children: const [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ].map((label) {
                      return Container(
                        height: cellHeight + cellSpacing,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: compact ? 9.5 : 11,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 14),

          // Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$activeDaysCount active days',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2B2D33) : const Color(0xFFE2E4E9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withAlpha(120),
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

  Widget _buildMonthHeaders(ThemeData theme, List<List<DateTime>> weeks, double colWidth) {
    final List<Widget> headers = [];
    int lastMonth = -1;

    for (int i = 0; i < weeks.length; i++) {
      final firstDayOfWeek = weeks[i][0];
      final currentMonth = firstDayOfWeek.month;

      if (currentMonth != lastMonth) {
        lastMonth = currentMonth;
        final label = i == 0
            ? DateFormat('MMM yyyy').format(firstDayOfWeek)
            : DateFormat('MMM').format(firstDayOfWeek);

        headers.add(
          SizedBox(
            width: colWidth * 2.8,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: compact ? 10 : 11.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withAlpha(170),
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
    required double cellWidth,
    required double cellHeight,
    required double spacing,
    required bool showNumber,
  }) {
    final minutes = attendance?.totalDuration.inMinutes ?? 0;
    final isActive = minutes > 0;

    // Reference styling from Image 1:
    // Active: Vibrant Coral-Orange (#FF5722) with white text
    // Inactive past: Dark slate (#2B2D33) with clear light-grey text (#C2C5D0)
    // Future: Faint transparent dark (#1C1E23)
    final Color bgColor = isFuture
        ? (isDark ? const Color(0xFF1B1C21) : const Color(0xFFF3F4F6))
        : isActive
            ? const Color(0xFFFF5722)
            : (isDark ? const Color(0xFF2C2E34) : const Color(0xFFE2E4E9));

    final Color textColor = isFuture
        ? (isDark ? const Color(0xFF454853) : const Color(0xFF9CA3AF))
        : isActive
            ? Colors.white
            : (isDark ? const Color(0xFFC4C8D4) : const Color(0xFF374151));

    final dateFormatted = DateFormat('EEE, MMM d').format(date);
    final tooltipText = isFuture
        ? '$dateFormatted (Upcoming)'
        : isActive
            ? '$dateFormatted: ${attendance!.formattedTotalDuration} (${attendance.sessions.length} sessions)'
            : '$dateFormatted: No work recorded';

    return Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 150),
      child: Container(
        width: cellWidth,
        height: cellHeight,
        margin: EdgeInsets.all(spacing / 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive
                ? const Color(0xFFFF6E40)
                : (isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(8)),
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: showNumber
            ? Text(
                date.day.toString(),
                style: TextStyle(
                  color: textColor,
                  fontSize: compact ? 9.5 : 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  height: 1.0,
                ),
              )
            : null,
      ),
    );
  }

  String _dateStr(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
