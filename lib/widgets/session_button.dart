import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SessionButton extends StatefulWidget {
  final StorageService storage;

  const SessionButton({super.key, required this.storage});

  @override
  State<SessionButton> createState() => _SessionButtonState();
}

class _SessionButtonState extends State<SessionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.storage.addListener(_onStorageChange);
    _updatePulse();
  }

  void _onStorageChange() {
    if (mounted) {
      setState(() {});
      _updatePulse();
    }
  }

  void _updatePulse() {
    if (widget.storage.hasActiveSession) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    widget.storage.removeListener(_onStorageChange);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onPressed() async {
    final isActive = widget.storage.hasActiveSession;

    if (isActive) {
      final time = await widget.storage.clockOut();
      if (mounted) {
        _showConfirmation(false, time);
      }
    } else {
      final time = await widget.storage.clockIn();
      if (mounted) {
        _showConfirmation(true, time);
      }
    }
  }

  void _showConfirmation(bool isIn, DateTime time) {
    final timeStr = TimeOfDay.fromDateTime(time).format(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
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
              isIn ? 'IN recorded  •  $timeStr' : 'OUT recorded  •  $timeStr',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.storage.hasActiveSession;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, right: 8),
      child: ScaleTransition(
        scale: isActive ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
        child: GestureDetector(
          onTap: _onPressed,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: isActive ? AppTheme.endGradient : AppTheme.startGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isActive ? AppTheme.errorRed : AppTheme.accentTeal)
                      .withAlpha(100),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
