import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_day.dart';
import '../../services/storage_service.dart';
import '../../theme/windows_acrylic_theme.dart';
import 'acrylic_section.dart';
import 'glass_icon_button.dart';

/// Clean Windows 11 Light Acrylic Monthly Calendar widget
class WindowsCalendarCard extends StatefulWidget {
  final StorageService storage;
  final bool compact;

  const WindowsCalendarCard({
    super.key,
    required this.storage,
    this.compact = false,
  });

  @override
  State<WindowsCalendarCard> createState() => _WindowsCalendarCardState();
}

class _WindowsCalendarCardState extends State<WindowsCalendarCard> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
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

  void _prevMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _displayedMonth = DateTime(now.year, now.month, 1);
    });
  }

  String _dateStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final monthYearStr = DateFormat('MMMM yyyy').format(_displayedMonth);

    // Map existing days by date string "yyyy-MM-dd"
    final Map<String, AttendanceDay> dayMap = {};
    for (final day in widget.storage.attendanceDays) {
      dayMap[day.date] = day;
    }

    // Calculate total logged time for displayed month
    Duration monthTotalDuration = Duration.zero;
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, d);
      final att = dayMap[_dateStr(date)];
      if (att != null) {
        monthTotalDuration += att.totalDuration;
      }
    }

    // Month Grid Calculation: Monday to Sunday
    // firstWeekday: 1 (Mon) to 7 (Sun)
    final firstWeekday = _displayedMonth.weekday;
    final daysBefore = firstWeekday - 1;
    final startDate = _displayedMonth.subtract(Duration(days: daysBefore));

    // Calculate total rows (5 or 6)
    final totalDays = daysBefore + daysInMonth;
    final rows = (totalDays / 7).ceil();

    return AcrylicSection(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Month & Year + Navigation Arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _goToToday,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    monthYearStr,
                    style: WindowsAcrylicTheme.title(
                      size: 13,
                      weight: FontWeight.w600,
                      color: WindowsAcrylicTheme.textPrimary,
                    ),
                  ),
                ),
              ),

              // Navigation controls (< >)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Previous month',
                    size: 24,
                    iconSize: 17,
                    onTap: _prevMonth,
                  ),
                  const SizedBox(width: 4),
                  GlassIconButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Next month',
                    size: 24,
                    iconSize: 17,
                    onTap: _nextMonth,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Day of week labels: M T W T F S S
          Row(
            children: const [
              _DayHeaderLabel('M'),
              _DayHeaderLabel('T'),
              _DayHeaderLabel('W'),
              _DayHeaderLabel('T'),
              _DayHeaderLabel('F'),
              _DayHeaderLabel('S'),
              _DayHeaderLabel('S'),
            ],
          ),
          const SizedBox(height: 6),

          // Monthly Calendar Grid
          for (int r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  for (int c = 0; c < 7; c++) ...[
                    Expanded(
                      child: _buildDayCell(
                        date: startDate.add(Duration(days: r * 7 + c)),
                        today: today,
                        dayMap: dayMap,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 10),

          // Divider
          Container(
            height: 1,
            color: WindowsAcrylicTheme.divider,
          ),
          const SizedBox(height: 8),

          // Bottom Bar: Legend and Total Logged
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Legend (● Active, ○ No session)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: WindowsAcrylicTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: WindowsAcrylicTheme.caption(
                      size: 9.5,
                      color: WindowsAcrylicTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: WindowsAcrylicTheme.textMuted,
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'No session',
                    style: WindowsAcrylicTheme.caption(
                      size: 9.5,
                      color: WindowsAcrylicTheme.textMuted,
                    ),
                  ),
                ],
              ),

              // Total logged summary
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total logged  ',
                    style: WindowsAcrylicTheme.caption(
                      size: 10,
                      color: WindowsAcrylicTheme.textSecondary,
                    ),
                  ),
                  Text(
                    _formatDuration(monthTotalDuration),
                    style: WindowsAcrylicTheme.title(
                      size: 11,
                      weight: FontWeight.w600,
                      color: WindowsAcrylicTheme.primary,
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

  Widget _buildDayCell({
    required DateTime date,
    required DateTime today,
    required Map<String, AttendanceDay> dayMap,
  }) {
    final isCurrentMonth = date.month == _displayedMonth.month;
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    final attendance = dayMap[_dateStr(date)];
    final hasActiveSession =
        attendance != null && attendance.totalDuration.inMinutes > 0;

    return _CalendarDayCell(
      dayNumber: date.day,
      isCurrentMonth: isCurrentMonth,
      isToday: isToday,
      hasSession: hasActiveSession,
      attendance: attendance,
      date: date,
    );
  }
}

/// Day of week label (M, T, W, ...)
class _DayHeaderLabel extends StatelessWidget {
  final String text;

  const _DayHeaderLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontFamilyFallback: WindowsAcrylicTheme.fontFallbacks,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: WindowsAcrylicTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Individual Day Cell in Windows 11 Acrylic Calendar
class _CalendarDayCell extends StatefulWidget {
  final int dayNumber;
  final bool isCurrentMonth;
  final bool isToday;
  final bool hasSession;
  final AttendanceDay? attendance;
  final DateTime date;

  const _CalendarDayCell({
    required this.dayNumber,
    required this.isCurrentMonth,
    required this.isToday,
    required this.hasSession,
    required this.attendance,
    required this.date,
  });

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _isHovered = false;

  void _showDetails(BuildContext context) {
    if (widget.attendance == null || widget.attendance!.sessions.isEmpty) return;

    final dateTitle = DateFormat('EEEE, MMM d, yyyy').format(widget.date);
    final duration = widget.attendance!.formattedTotalDuration;
    final count = widget.attendance!.sessions.length;

    showDialog(
      context: context,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(245),
                borderRadius: BorderRadius.circular(WindowsAcrylicTheme.radiusCard),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: WindowsAcrylicTheme.ambientShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateTitle,
                        style: WindowsAcrylicTheme.title(size: 12),
                      ),
                      GlassIconButton(
                        icon: Icons.close_rounded,
                        size: 20,
                        iconSize: 14,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Logged: $duration across $count session${count == 1 ? '' : 's'}',
                    style: WindowsAcrylicTheme.subtitle(
                      size: 11,
                      color: WindowsAcrylicTheme.primary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...widget.attendance!.sessions.map((s) {
                    final inStr = DateFormat('h:mm a').format(s.inTime);
                    final outStr = s.outTime != null
                        ? DateFormat('h:mm a').format(s.outTime!)
                        : 'Active';
                    final tagStr = s.tag != null ? ' • ${s.tag}' : '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• $inStr – $outStr ($tagStr)',
                        style: WindowsAcrylicTheme.caption(
                          size: 10.5,
                          color: WindowsAcrylicTheme.textSecondary,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine cell colors
    Color textColor;
    if (!widget.isCurrentMonth) {
      textColor = const Color(0xFFBDC1C6); // Very subtle inactive date
    } else if (widget.isToday) {
      textColor = WindowsAcrylicTheme.primary;
    } else {
      textColor = WindowsAcrylicTheme.textPrimary;
    }

    final cellBg = widget.isToday
        ? WindowsAcrylicTheme.lightAccent
        : (_isHovered ? const Color(0x0E0067C0) : Colors.transparent);

    final border = widget.isToday
        ? Border.all(
            color: WindowsAcrylicTheme.primary.withAlpha(70),
            width: 0.8,
          )
        : null;

    return MouseRegion(
      cursor: widget.hasSession ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.hasSession ? () => _showDetails(context) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1),
          decoration: BoxDecoration(
            color: cellBg,
            borderRadius: BorderRadius.circular(6),
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.dayNumber}',
                style: TextStyle(
                  fontFamilyFallback: WindowsAcrylicTheme.fontFallbacks,
                  fontSize: 11,
                  fontWeight: widget.isToday
                      ? FontWeight.w700
                      : (widget.isCurrentMonth ? FontWeight.w500 : FontWeight.w400),
                  color: textColor,
                ),
              ),
              if (widget.isCurrentMonth && widget.hasSession) ...[
                const SizedBox(height: 1.5),
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: const BoxDecoration(
                    color: WindowsAcrylicTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 5),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
