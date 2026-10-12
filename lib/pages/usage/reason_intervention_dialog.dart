import 'package:flutter/material.dart';
import '../../models/app_restriction.dart';
import '../../models/usage_reason.dart';
import '../../models/usage_session.dart';
import '../../services/storage_service.dart';
import '../../services/app_usage_service.dart';
import '../../theme/app_theme.dart';

/// Modal dialog / full-screen conscious intervention prompt.
/// Enforces behavioral reflection before granting access to a restricted app.
class ReasonInterventionDialog extends StatefulWidget {
  final StorageService storage;
  final String packageId;
  final String appName;
  final UsageMode mode;
  final List<int> allowedPresets;
  final VoidCallback? onAllowed;
  final VoidCallback? onDenied;

  const ReasonInterventionDialog({
    super.key,
    required this.storage,
    required this.packageId,
    required this.appName,
    this.mode = UsageMode.normal,
    this.allowedPresets = const [1, 2, 3, 5, 10, 15, 30],
    this.onAllowed,
    this.onDenied,
  });

  /// Static helper to display the conscious intervention dialog.
  static Future<bool> show({
    required BuildContext context,
    required StorageService storage,
    required String packageId,
    required String appName,
    UsageMode mode = UsageMode.normal,
    List<int> allowedPresets = const [1, 2, 3, 5, 10, 15, 30],
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReasonInterventionDialog(
        storage: storage,
        packageId: packageId,
        appName: appName,
        mode: mode,
        allowedPresets: allowedPresets,
      ),
    );
    return result ?? false;
  }

  @override
  State<ReasonInterventionDialog> createState() => _ReasonInterventionDialogState();
}

class _ReasonInterventionDialogState extends State<ReasonInterventionDialog> {
  final ReasonCategory _selectedCategory = ReasonCategory.other;
  final TextEditingController _reasonController = TextEditingController();
  late int _selectedDurationMinutes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDurationMinutes = widget.allowedPresets.isNotEmpty ? widget.allowedPresets.first : 10;
    _reasonController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final explanation = _reasonController.text.trim();
    if (explanation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type your conscious reason before continuing.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final now = DateTime.now();
      final expires = now.add(Duration(minutes: _selectedDurationMinutes));
      final sessionId = 'sess_${now.millisecondsSinceEpoch}';
      final reasonId = 'reas_${now.millisecondsSinceEpoch}';

      // 1. Record Usage Session
      final session = UsageSession(
        id: sessionId,
        packageId: widget.packageId,
        appName: widget.appName,
        mode: widget.mode.name,
        startedAt: now.toIso8601String(),
        expiresAt: expires.toIso8601String(),
        requestedDurationMinutes: _selectedDurationMinutes,
        reasonId: reasonId,
        status: SessionStatus.active,
      );
      await widget.storage.startUsageSession(session);

      // 2. Record Usage Reason
      final reason = UsageReason(
        id: reasonId,
        sessionId: sessionId,
        packageId: widget.packageId,
        appName: widget.appName,
        mode: widget.mode.name,
        timestamp: now.toIso8601String(),
        category: _selectedCategory,
        customReason: explanation.isNotEmpty ? explanation : null,
        requestedMinutes: _selectedDurationMinutes,
        approvedMinutes: _selectedDurationMinutes,
        wasAllowed: true,
      );
      await widget.storage.addUsageReason(reason);

      // 3. Grant temporary access on native platform
      await AppUsageService.grantTemporaryAccess(
        packageId: widget.packageId,
        durationMinutes: _selectedDurationMinutes,
        reason: explanation.isNotEmpty ? explanation : _selectedCategory.name,
      );

      if (mounted) {
        widget.onAllowed?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _handleCancel() {
    // Record cancelled attempt
    final now = DateTime.now();
    final reasonId = 'reas_cancel_${now.millisecondsSinceEpoch}';
    final reason = UsageReason(
      id: reasonId,
      sessionId: 'none',
      packageId: widget.packageId,
      appName: widget.appName,
      mode: widget.mode.name,
      timestamp: now.toIso8601String(),
      category: _selectedCategory,
      customReason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : 'Cancelled reflection',
      requestedMinutes: _selectedDurationMinutes,
      approvedMinutes: 0,
      wasAllowed: false,
    );
    widget.storage.addUsageReason(reason);

    widget.onDenied?.call();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top intentional notice
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentTeal.withAlpha(40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.self_improvement_rounded, size: 16, color: AppTheme.accentTeal),
                        const SizedBox(width: 6),
                        Text(
                          'Take a moment to reflect',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentTeal),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Question Title
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Why are you opening',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(160),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.appName}?',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Manual Reason Input (Mandatory for Conscious Awareness) ───
                Text(
                  'TYPE YOUR CONSCIOUS REASON (REQUIRED)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppTheme.accentTeal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Explain exactly why you need this app right now. Typing your intention builds conscious awareness.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reasonController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Type your reason here (e.g. Watching a specific educational tutorial)...',
                    hintStyle: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withAlpha(100)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(40)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 18),

                // Duration Selector
                Text(
                  'HOW LONG DO YOU NEED?',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: widget.allowedPresets.map((mins) {
                    final isSel = _selectedDurationMinutes == mins;
                    return ChoiceChip(
                      label: Text('$mins min'),
                      selected: isSel,
                      onSelected: (_) => setState(() => _selectedDurationMinutes = mins),
                      selectedColor: AppTheme.accentTeal.withAlpha(35),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? AppTheme.accentTeal : null,
                      ),
                      side: BorderSide(
                        color: isSel ? AppTheme.accentTeal : theme.colorScheme.outline.withAlpha(30),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Buttons: Leave App & Continue
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface.withAlpha(180),
                          side: BorderSide(color: theme.colorScheme.outline.withAlpha(50)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _handleCancel,
                        child: const Text('Cancel / Leave'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_submitting || _reasonController.text.trim().length < 3) ? null : _handleContinue,
                        child: _submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
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
