import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/storage_service.dart';
import '../../theme/windows_acrylic_theme.dart';
import 'acrylic_section.dart';

/// Compact Windows 11 Light Acrylic Dashboard widget
class DesktopDashboardCard extends StatefulWidget {
  final StorageService storage;
  final bool compact;

  const DesktopDashboardCard({
    super.key,
    required this.storage,
    this.compact = false,
  });

  @override
  State<DesktopDashboardCard> createState() => _DesktopDashboardCardState();
}

class _DesktopDashboardCardState extends State<DesktopDashboardCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.storage.addListener(_onUpdate);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.storage.hasActiveSession) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.storage.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Duration _getWeekDuration() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    Duration total = Duration.zero;
    for (final day in widget.storage.attendanceDays) {
      try {
        final parsed = DateTime.parse(day.date);
        if (!parsed.isBefore(monday) && !parsed.isAfter(sunday)) {
          total += day.totalDuration;
        }
      } catch (_) {}
    }
    return total;
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatLiveTimer() {
    if (!widget.storage.hasActiveSession) {
      return '00:00:00';
    }
    final inTime = widget.storage.today?.lastInTime;
    if (inTime == null) return '00:00:00';

    final diff = DateTime.now().difference(inTime);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _toggleAttendance() async {
    if (widget.storage.hasActiveSession) {
      await widget.storage.clockOut();
    } else {
      await widget.storage.clockIn();
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectSkill(String? skillName) async {
    final today = widget.storage.today;
    if (today == null || today.sessions.isEmpty) return;
    final lastIndex = today.sessions.length - 1;
    await widget.storage.tagSession(today.date, lastIndex, skillName);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.storage.hasActiveSession;
    final todayData = widget.storage.today;
    final todayDuration = todayData?.totalDuration ?? Duration.zero;
    final weekDuration = _getWeekDuration();

    // Active session tag
    final currentTag = (isActive && (todayData?.sessions.isNotEmpty ?? false))
        ? todayData!.sessions.last.tag
        : null;

    final formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return AcrylicSection(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Header date & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formattedDate,
                style: WindowsAcrylicTheme.subtitle(
                  size: 11.5,
                  weight: FontWeight.w500,
                  color: WindowsAcrylicTheme.textSecondary,
                ),
              ),
              // Working / Idle Status Indicator
              _StatusPill(isActive: isActive),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Live Timer and Compact Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Live Clock Timer
              Text(
                _formatLiveTimer(),
                style: WindowsAcrylicTheme.timer(
                  size: widget.compact ? 24 : 28,
                  weight: FontWeight.w600,
                  color: isActive
                      ? WindowsAcrylicTheme.textPrimary
                      : WindowsAcrylicTheme.textMuted,
                ),
              ),

              // Compact Windows 11 Action Button
              _ActionButton(
                isActive: isActive,
                onTap: _toggleAttendance,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Divider
          Container(
            height: 1,
            color: WindowsAcrylicTheme.divider,
          ),
          const SizedBox(height: 12),

          // Row 3: Stats (Today / This week)
          Row(
            children: [
              // Today
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: WindowsAcrylicTheme.caption(
                        size: 10.5,
                        color: WindowsAcrylicTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDuration(todayDuration),
                      style: WindowsAcrylicTheme.title(
                        size: 14,
                        weight: FontWeight.w600,
                        color: WindowsAcrylicTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Subtle vertical separator
              Container(
                width: 1,
                height: 26,
                color: WindowsAcrylicTheme.divider,
              ),
              const SizedBox(width: 16),

              // This week
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This week',
                      style: WindowsAcrylicTheme.caption(
                        size: 10.5,
                        color: WindowsAcrylicTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDuration(weekDuration),
                      style: WindowsAcrylicTheme.title(
                        size: 14,
                        weight: FontWeight.w600,
                        color: WindowsAcrylicTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Row 4: Quick Skill/Project Tags (if skills exist)
          if (widget.storage.skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: WindowsAcrylicTheme.divider,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    Icons.tag_rounded,
                    size: 13,
                    color: WindowsAcrylicTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  ...widget.storage.skills.map((skill) {
                    final isSelected = currentTag == skill.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _SkillChip(
                        label: skill.name,
                        isSelected: isSelected,
                        onTap: () {
                          if (isSelected) {
                            _selectSkill(null);
                          } else {
                            _selectSkill(skill.name);
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact Windows 11 status pill (● Working / ○ Idle)
class _StatusPill extends StatelessWidget {
  final bool isActive;

  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? WindowsAcrylicTheme.statusActiveBg
            : const Color(0x0C000000),
        borderRadius: BorderRadius.circular(WindowsAcrylicTheme.radiusPill),
        border: Border.all(
          color: isActive
              ? WindowsAcrylicTheme.statusActive.withAlpha(60)
              : Colors.black.withAlpha(15),
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
              color: isActive
                  ? WindowsAcrylicTheme.statusActive
                  : WindowsAcrylicTheme.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Working' : 'Idle',
            style: TextStyle(
              fontFamilyFallback: WindowsAcrylicTheme.fontFallbacks,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? WindowsAcrylicTheme.statusActive
                  : WindowsAcrylicTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact Windows 11 Action Button ([ Clock In ] / [ Clock Out ])
class _ActionButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _ActionButton({
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isOut = widget.isActive;

    // Windows 11 Button Styling
    final Color bgColor;
    final Color textColor;
    final Border? border;

    if (isOut) {
      // Clock Out: Clean outlined secondary button
      bgColor = _isHovered ? WindowsAcrylicTheme.statusOutBg : Colors.white.withAlpha(160);
      textColor = _isHovered ? WindowsAcrylicTheme.statusOut : WindowsAcrylicTheme.textPrimary;
      border = Border.all(
        color: _isHovered
            ? WindowsAcrylicTheme.statusOut.withAlpha(100)
            : const Color(0x2A000000),
        width: 1,
      );
    } else {
      // Clock In: Windows 11 Primary blue button
      bgColor = _isHovered ? WindowsAcrylicTheme.primaryHover : WindowsAcrylicTheme.primary;
      textColor = Colors.white;
      border = null;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(WindowsAcrylicTheme.radiusButton),
            border: border,
            boxShadow: [
              BoxShadow(
                color: (isOut ? Colors.black : WindowsAcrylicTheme.primary)
                    .withAlpha(_isHovered ? 25 : 12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOut ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 15,
                color: textColor,
              ),
              const SizedBox(width: 5),
              Text(
                isOut ? 'Clock Out' : 'Clock In',
                style: TextStyle(
                  fontFamilyFallback: WindowsAcrylicTheme.fontFallbacks,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact Skill Tag Chip
class _SkillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SkillChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? WindowsAcrylicTheme.lightAccent
              : Colors.white.withAlpha(120),
          borderRadius: BorderRadius.circular(WindowsAcrylicTheme.radiusPill),
          border: Border.all(
            color: isSelected
                ? WindowsAcrylicTheme.primary.withAlpha(60)
                : Colors.black.withAlpha(15),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamilyFallback: WindowsAcrylicTheme.fontFallbacks,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? WindowsAcrylicTheme.primary
                : WindowsAcrylicTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
