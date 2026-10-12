import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/storage_service.dart';
import '../../models/usage_reason.dart';
import '../../models/usage_session.dart';
import '../../theme/app_theme.dart';

/// Page displaying historical conscious app usage decisions, reasons, and active/past sessions.
class UsageHistoryPage extends StatefulWidget {
  final StorageService storage;

  const UsageHistoryPage({super.key, required this.storage});

  @override
  State<UsageHistoryPage> createState() => _UsageHistoryPageState();
}

class _UsageHistoryPageState extends State<UsageHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _timeFilter = 0; // 0: All, 1: Today, 2: 7 Days
  String? _selectedPackage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _matchesTimeFilter(String isoDate) {
    if (_timeFilter == 0) return true;
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return false;
    final now = DateTime.now();
    if (_timeFilter == 1) {
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }
    if (_timeFilter == 2) {
      return now.difference(dt).inDays <= 7;
    }
    return true;
  }

  List<UsageReason> get _filteredReasons {
    final reasons = widget.storage.usageReasons.where((r) {
      if (!_matchesTimeFilter(r.timestamp)) return false;
      if (_selectedPackage != null && r.packageId != _selectedPackage) return false;
      return true;
    }).toList();
    reasons.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return reasons;
  }

  List<UsageSession> get _filteredSessions {
    final sessions = widget.storage.usageSessions.where((s) {
      if (!_matchesTimeFilter(s.startedAt)) return false;
      if (_selectedPackage != null && s.packageId != _selectedPackage) return false;
      return true;
    }).toList();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reasons = _filteredReasons;
    final sessions = _filteredSessions;

    // Stats
    final totalRequests = reasons.length;
    final approved = reasons.where((r) => r.wasAllowed).length;
    final totalApprovedMinutes = reasons.fold(0, (sum, r) => sum + r.approvedMinutes);

    // Packages list for filter
    final uniquePackages = <String>{
      ...widget.storage.usageReasons.map((r) => r.packageId),
      ...widget.storage.usageSessions.map((s) => s.packageId),
    }.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conscious Usage History'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentTeal,
          labelColor: AppTheme.accentTeal,
          unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(140),
          tabs: [
            Tab(text: 'Reasons ($totalRequests)'),
            Tab(text: 'Sessions (${sessions.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Filter Bar (Scrollable to prevent overflow on all screen sizes) ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Time Filter Chips
                  _buildTimeFilterChip('All Time', 0),
                  const SizedBox(width: 6),
                  _buildTimeFilterChip('Today', 1),
                  const SizedBox(width: 6),
                  _buildTimeFilterChip('Last 7 Days', 2),
                  const SizedBox(width: 14),
                  // Package Dropdown
                  if (uniquePackages.isNotEmpty)
                    DropdownButton<String?>(
                      value: _selectedPackage,
                      hint: Text('Filter App', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(150))),
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Apps', style: TextStyle(fontSize: 12))),
                        ...uniquePackages.map((pkg) {
                          final name = widget.storage.appRestrictions
                                  .where((r) => r.packageId == pkg)
                                  .firstOrNull
                                  ?.appName ??
                              pkg.split('.').last;
                          return DropdownMenuItem(
                            value: pkg,
                            child: Text(name, style: const TextStyle(fontSize: 12)),
                          );
                        }),
                      ],
                      onChanged: (val) => setState(() => _selectedPackage = val),
                    ),
                ],
              ),
            ),
          ),

          // ─── Metrics Summary ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _buildMetricCard(theme, 'Requests', '$totalRequests', Icons.touch_app_rounded, AppTheme.accentTeal),
                const SizedBox(width: 10),
                _buildMetricCard(theme, 'Approved', '$approved', Icons.check_circle_outline_rounded, const Color(0xFF10B981)),
                const SizedBox(width: 10),
                _buildMetricCard(theme, 'Intentional Time', '${totalApprovedMinutes}m', Icons.timer_outlined, AppTheme.accentCyan),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── Content Tabs ───
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReasonsList(reasons, theme),
                _buildSessionsList(sessions, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterChip(String label, int index) {
    final isSelected = _timeFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _timeFilter = index),
      selectedColor: AppTheme.accentTeal.withAlpha(35),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.accentTeal : null,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.accentTeal : Theme.of(context).colorScheme.outline.withAlpha(30),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
    );
  }

  Widget _buildMetricCard(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withAlpha(140)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonsList(List<UsageReason> reasons, ThemeData theme) {
    if (reasons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 48, color: theme.colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 12),
            Text(
              'No conscious reason records yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'When you open a restricted app and explain why, it will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(110)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: reasons.length,
      itemBuilder: (context, index) {
        final reason = reasons[index];
        final dt = DateTime.tryParse(reason.timestamp);
        final formattedDate = dt != null ? DateFormat('MMM d, h:mm a').format(dt) : reason.timestamp;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(30),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withAlpha(25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(reason.category == ReasonCategory.other ? '✍️' : reason.category.icon, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          reason.category == ReasonCategory.other ? 'Conscious Reason' : reason.category.displayName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason.appName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(110)),
                  ),
                ],
              ),

              // Explanation Bubble
              if (reason.customReason != null && reason.customReason!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(150),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline.withAlpha(15)),
                  ),
                  child: Text(
                    '"${reason.customReason}"',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withAlpha(200),
                    ),
                  ),
                ),
              ],

              // Footer: Duration & Approval status
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          reason.wasAllowed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 15,
                          color: reason.wasAllowed ? const Color(0xFF10B981) : AppTheme.errorRed,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reason.wasAllowed
                                ? 'Approved for ${reason.approvedMinutes} min'
                                : 'Request cancelled',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: reason.wasAllowed ? const Color(0xFF10B981) : AppTheme.errorRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      reason.mode.toUpperCase(),
                      style: TextStyle(fontSize: 9.5, color: theme.colorScheme.onSurface.withAlpha(130), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionsList(List<UsageSession> sessions, ThemeData theme) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: theme.colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 12),
            Text(
              'No usage sessions recorded yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final startDt = DateTime.tryParse(session.startedAt);
        final startStr = startDt != null ? DateFormat('MMM d, h:mm a').format(startDt) : session.startedAt;

        Color statusColor;
        switch (session.status) {
          case SessionStatus.active:
            statusColor = const Color(0xFF10B981);
            break;
          case SessionStatus.completed:
            statusColor = AppTheme.accentTeal;
            break;
          case SessionStatus.expired:
            statusColor = AppTheme.warningAmber;
            break;
          case SessionStatus.blocked:
          case SessionStatus.cancelled:
            statusColor = AppTheme.errorRed;
            break;
          default:
            statusColor = theme.colorScheme.onSurface.withAlpha(120);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withAlpha(20)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.appName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      startStr,
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(120)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      session.status.displayName,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.requestedDurationMinutes} min',
                    style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withAlpha(140)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
