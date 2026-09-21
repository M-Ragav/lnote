import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/attendance_day.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';

class DayDetailsPage extends StatefulWidget {
  final StorageService storage;
  final String dateStr;

  const DayDetailsPage({
    super.key,
    required this.storage,
    required this.dateStr,
  });

  @override
  State<DayDetailsPage> createState() => _DayDetailsPageState();
}

class _DayDetailsPageState extends State<DayDetailsPage> {
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
    final day = widget.storage.getAttendanceForDate(widget.dateStr);
    final date = DateTime.parse(widget.dateStr);
    final dayName = DateFormat('EEEE').format(date);
    final dateFormatted = DateFormat('MMMM d').format(date);

    return Scaffold(
      appBar: AppBar(
        title: Text(dateFormatted),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: day == null || day.sessions.isEmpty
          ? _buildEmpty(theme)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day name
                  Text(
                    dayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section title
                  Text(
                    'Today\'s Sessions',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Sessions list
                  ...List.generate(day.sessions.length, (i) {
                    return _buildSessionCard(
                      theme,
                      day.sessions[i],
                      i,
                      i + 1,
                    );
                  }),

                  const SizedBox(height: 8),

                  // Total card
                  _buildTotalCard(theme, day),

                  const SizedBox(height: 12),

                  // Summary row
                  _buildSummaryRow(theme, day),
                ],
              ),
            ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 56,
            color: theme.colorScheme.onSurface.withAlpha(51),
          ),
          const SizedBox(height: 16),
          Text(
            'No sessions recorded',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    ThemeData theme,
    Session session,
    int sessionIndex,
    int number,
  ) {
    final hasTag = session.tag != null && session.tag!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
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
        children: [
          // Session header with tag chip/button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session ${number.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentTeal.withAlpha(179),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              _buildTagChip(theme, session, sessionIndex),
            ],
          ),
          const SizedBox(height: 14),

          // IN row
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.successGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text('IN', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(
                DateFormat('h:mm a').format(session.inTime),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dotted connector
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              children: List.generate(
                3,
                (_) => Container(
                  width: 2,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 3),
                  color: theme.colorScheme.onSurface.withAlpha(51),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // OUT row
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: session.outTime != null
                      ? AppTheme.errorRed
                      : AppTheme.warningAmber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                session.outTime != null ? 'OUT' : '⚠ OUT not recorded',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: session.outTime == null ? AppTheme.warningAmber : null,
                ),
              ),
              const Spacer(),
              if (session.outTime != null)
                Text(
                  DateFormat('h:mm a').format(session.outTime!),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),

          // Duration & tagging hint
          if (session.outTime != null) ...[
            const SizedBox(height: 14),
            Divider(color: theme.colorScheme.outline.withAlpha(51)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurface.withAlpha(102),
                ),
                const SizedBox(width: 6),
                Text(
                  'Duration: ${session.formattedDuration}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withAlpha(153),
                  ),
                ),
                if (!hasTag) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showTagPickerSheet(context, sessionIndex, session.tag),
                    child: Text(
                      '+ Add tag',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.accentTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagChip(ThemeData theme, Session session, int sessionIndex) {
    final hasTag = session.tag != null && session.tag!.trim().isNotEmpty;

    if (hasTag) {
      return InkWell(
        onTap: () => _showTagPickerSheet(context, sessionIndex, session.tag),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accentTeal.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.accentTeal.withAlpha(100),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 12,
                color: AppTheme.accentTeal,
              ),
              const SizedBox(width: 5),
              Text(
                session.tag!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentTeal,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 14,
                color: AppTheme.accentTeal.withAlpha(180),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showTagPickerSheet(context, sessionIndex, session.tag),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withAlpha(12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(60),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tag_rounded,
              size: 12,
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
            const SizedBox(width: 4),
            Text(
              'Tag',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(140),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTagPickerSheet(
    BuildContext context,
    int sessionIndex,
    String? currentTag,
  ) {
    final theme = Theme.of(context);
    final skills = widget.storage.skills;
    final customTagController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(sheetContext).viewInsets.bottom + 28,
            ),
            child: SingleChildScrollView(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tag Session',
                        style: theme.textTheme.headlineMedium,
                      ),
                      if (currentTag != null)
                        TextButton(
                          onPressed: () async {
                            await widget.storage.tagSession(
                              widget.dateStr,
                              sessionIndex,
                              null,
                            );
                            if (mounted) setState(() {});
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          },
                          child: const Text(
                            'Clear Tag',
                            style: TextStyle(
                              color: AppTheme.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Link this session to a skill to track toward 10,000 hours',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),

                  // Skills list
                  if (skills.isNotEmpty) ...[
                    Text(
                      'YOUR SKILLS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: skills.map((skill) {
                        final isSelected = currentTag == skill.name;
                        return ChoiceChip(
                          label: Text(skill.name),
                          selected: isSelected,
                          selectedColor: AppTheme.accentTeal.withAlpha(50),
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.accentTeal
                                : theme.colorScheme.outline.withAlpha(80),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.accentTeal
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          onSelected: (selected) async {
                            if (selected) {
                              await widget.storage.tagSession(
                                widget.dateStr,
                                sessionIndex,
                                skill.name,
                              );
                              if (mounted) setState(() {});
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Custom Tag
                  Text(
                    'CUSTOM TAG',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customTagController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Enter custom tag name',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(80),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outline.withAlpha(100),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outline.withAlpha(100),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.accentTeal,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.accentTeal,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                        ),
                        onPressed: () async {
                          final customName = customTagController.text.trim();
                          if (customName.isNotEmpty) {
                            await widget.storage.tagSession(
                              widget.dateStr,
                              sessionIndex,
                              customName,
                            );
                            if (mounted) setState(() {});
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalCard(ThemeData theme, AttendanceDay day) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentTeal.withAlpha(20),
            AppTheme.accentCyan.withAlpha(10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentTeal.withAlpha(51),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.accentTeal.withAlpha(179),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.accentGradient.createShader(bounds),
            child: Text(
              day.formattedTotalDuration,
              style: theme.textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, AttendanceDay day) {
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '${day.totalInCount}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.successGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text('Total IN', style: theme.textTheme.bodySmall),
            ],
          ),
          Container(
            width: 1,
            height: 36,
            color: theme.colorScheme.outline.withAlpha(77),
          ),
          Column(
            children: [
              Text(
                '${day.totalOutCount}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.errorRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text('Total OUT', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
