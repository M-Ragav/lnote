import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'day_details_page.dart';

class CalendarPage extends StatefulWidget {
  final StorageService storage;

  const CalendarPage({super.key, required this.storage});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
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
    final days = widget.storage.sortedDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: days.isEmpty
          ? _buildEmpty(theme)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                return _buildDayCard(theme, day);
              },
            ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(51),
          ),
          const SizedBox(height: 16),
          Text(
            'No records yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(102),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a work session to see your history',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(ThemeData theme, dynamic day) {
    final date = DateTime.parse(day.date);
    final dayName = DateFormat('EEEE').format(date);
    final dateStr = DateFormat('MMMM d, yyyy').format(date);
    final lastIn = day.lastInTime;
    final lastOut = day.lastOutTime;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DayDetailsPage(
                storage: widget.storage,
                dateStr: day.date,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withAlpha(77),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // Date column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Last IN / OUT
                    Row(
                      children: [
                        _timeChip(
                          theme,
                          'Last IN',
                          lastIn != null
                              ? DateFormat('h:mm a').format(lastIn)
                              : '—',
                          AppTheme.successGreen,
                        ),
                        const SizedBox(width: 12),
                        _timeChip(
                          theme,
                          'Last OUT',
                          lastOut != null
                              ? DateFormat('h:mm a').format(lastOut)
                              : '—',
                          AppTheme.errorRed,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withAlpha(77),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeChip(
      ThemeData theme, String label, String time, Color dotColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor.withAlpha(179),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: theme.colorScheme.onSurface.withAlpha(102),
              ),
            ),
            Text(
              time,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(204),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
