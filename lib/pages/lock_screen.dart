import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';

/// Full-screen Lock Screen requiring 4-digit PIN or Biometric authentication
class LockScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onUnlocked;

  const LockScreen({
    super.key,
    required this.storage,
    required this.onUnlocked,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isAuthenticatingBiometrics = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    // Auto-prompt biometrics if enabled
    if (widget.storage.isBiometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _authenticateBiometric();
        });
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _authenticateBiometric() async {
    if (_isAuthenticatingBiometrics) return;
    setState(() => _isAuthenticatingBiometrics = true);

    try {
      final success = await BiometricService.authenticate(
        reason: 'Authenticate to unlock LNote',
      );
      if (success && mounted) {
        HapticFeedback.mediumImpact();
        widget.onUnlocked();
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticatingBiometrics = false);
      }
    }
  }

  void _onKeyPress(String digit) {
    HapticFeedback.lightImpact();
    if (_enteredPin.length < 4) {
      setState(() {
        _errorMessage = null;
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _verifyPin(_enteredPin);
      }
    }
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _verifyPin(String pin) {
    if (widget.storage.verifyPin(pin)) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'Incorrect PIN. Try again.';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // App Logo & Lock Badge
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB0100),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withAlpha(80)
                                  : AppTheme.accentTeal.withAlpha(40),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/logopng.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentTeal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  Text(
                    'LNote is Locked',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.storage.isBiometricEnabled
                        ? 'Enter 4-digit PIN or authenticate with biometrics'
                        : 'Enter your 4-digit PIN to continue',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // 4 Dots with shake animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _shakeController.isAnimating
                              ? (_shakeAnimation.value * (_enteredPin.isEmpty ? 1 : -1))
                              : 0.0,
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final isFilled = i < _enteredPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? AppTheme.accentTeal : Colors.transparent,
                            border: Border.all(
                              color: isFilled
                                  ? AppTheme.accentTeal
                                  : theme.colorScheme.onSurface.withAlpha(60),
                              width: 2,
                            ),
                            boxShadow: isFilled
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accentTeal.withAlpha(80),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    height: 20,
                    child: _errorMessage != null
                        ? Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.errorRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),

                  const Spacer(flex: 3),

                  // Keypad
                  Column(
                    children: [
                      _buildKeypadRow(['1', '2', '3'], theme),
                      const SizedBox(height: 14),
                      _buildKeypadRow(['4', '5', '6'], theme),
                      const SizedBox(height: 14),
                      _buildKeypadRow(['7', '8', '9'], theme),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Biometric button (if enabled)
                          SizedBox(
                            width: 76,
                            height: 60,
                            child: widget.storage.isBiometricEnabled
                                ? IconButton(
                                    onPressed: _authenticateBiometric,
                                    icon: const Icon(
                                      Icons.fingerprint_rounded,
                                      size: 32,
                                      color: AppTheme.accentCyan,
                                    ),
                                    tooltip: 'Use Biometrics',
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 14),
                          _buildKeypadButton('0', theme),
                          const SizedBox(width: 14),
                          // Backspace
                          SizedBox(
                            width: 76,
                            height: 60,
                            child: IconButton(
                              onPressed: _onBackspace,
                              icon: const Icon(Icons.backspace_outlined, size: 22),
                              color: theme.colorScheme.onSurface.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: _buildKeypadButton(d, theme),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton(String digit, ThemeData theme) {
    return Container(
      width: 76,
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(35),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onKeyPress(digit),
          child: Center(
            child: Text(
              digit,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
