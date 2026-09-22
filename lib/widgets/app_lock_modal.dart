import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet to setup, configure, change, or disable App Lock
class AppLockModal extends StatefulWidget {
  final StorageService storage;

  const AppLockModal({super.key, required this.storage});

  static Future<void> show(BuildContext context, StorageService storage) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppLockModal(storage: storage),
    );
  }

  @override
  State<AppLockModal> createState() => _AppLockModalState();
}

enum _ModalView {
  manage, // View current settings (Change PIN, Biometrics toggle, Disable)
  setupFirstPin, // Enter new 4-digit PIN
  setupConfirmPin, // Confirm new 4-digit PIN
  verifyCurrentForChange, // Verify old PIN before changing
  verifyCurrentForDisable, // Verify old PIN before disabling
}

class _AppLockModalState extends State<AppLockModal> {
  late _ModalView _view;
  String _enteredPin = '';
  String _firstPin = '';
  String? _errorMessage;
  bool _deviceSupportsBiometrics = false;
  String _biometricLabel = 'Biometrics';

  @override
  void initState() {
    super.initState();
    _view = widget.storage.isAppLockEnabled ? _ModalView.manage : _ModalView.setupFirstPin;
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final can = await BiometricService.canAuthenticate();
    final label = await BiometricService.getBiometricName();
    if (mounted) {
      setState(() {
        _deviceSupportsBiometrics = can;
        _biometricLabel = label;
      });
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
        _handlePinComplete(_enteredPin);
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

  Future<void> _handlePinComplete(String pin) async {
    switch (_view) {
      case _ModalView.setupFirstPin:
        setState(() {
          _firstPin = pin;
          _enteredPin = '';
          _view = _ModalView.setupConfirmPin;
        });
        break;

      case _ModalView.setupConfirmPin:
        if (pin == _firstPin) {
          await widget.storage.setAppPin(
            pin,
            enableBiometric: _deviceSupportsBiometrics,
          );
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.successGreen),
                    const SizedBox(width: 10),
                    Text('App Lock enabled with 4-digit PIN!'),
                  ],
                ),
                backgroundColor: const Color(0xFF1E293B),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _errorMessage = 'PINs did not match. Please try again.';
            _enteredPin = '';
            _view = _ModalView.setupFirstPin;
          });
        }
        break;

      case _ModalView.verifyCurrentForChange:
        if (widget.storage.verifyPin(pin)) {
          setState(() {
            _enteredPin = '';
            _view = _ModalView.setupFirstPin;
          });
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _errorMessage = 'Incorrect PIN. Try again.';
            _enteredPin = '';
          });
        }
        break;

      case _ModalView.verifyCurrentForDisable:
        if (widget.storage.verifyPin(pin)) {
          await widget.storage.disableAppLock(currentPin: pin);
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('App Lock has been disabled'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _errorMessage = 'Incorrect PIN. Try again.';
            _enteredPin = '';
          });
        }
        break;

      case _ModalView.manage:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            if (_view == _ModalView.manage) ...[
              _buildManageView(theme),
            ] else ...[
              _buildKeypadView(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManageView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.accentTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Lock',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Protected with 4-digit PIN',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.successGreen.withAlpha(60),
                    width: 0.5,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: AppTheme.successGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Biometrics toggle (if supported)
          if (_deviceSupportsBiometrics) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outline.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, size: 24, color: AppTheme.accentCyan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock with $_biometricLabel',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Use biometric authentication alongside PIN',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: widget.storage.isBiometricEnabled,
                    activeTrackColor: AppTheme.accentTeal,
                    onChanged: (val) => widget.storage.setBiometricEnabled(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Change PIN tile
          _buildActionRow(
            theme,
            icon: Icons.pin_outlined,
            title: 'Change 4-Digit PIN',
            subtitle: 'Update your security passcode',
            onTap: () {
              setState(() {
                _view = _ModalView.verifyCurrentForChange;
                _enteredPin = '';
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 10),

          // Turn off App Lock
          _buildActionRow(
            theme,
            icon: Icons.lock_open_rounded,
            title: 'Turn Off App Lock',
            subtitle: 'Removes PIN and biometric protection',
            iconColor: AppTheme.errorRed,
            onTap: () {
              setState(() {
                _view = _ModalView.verifyCurrentForDisable;
                _enteredPin = '';
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline.withAlpha(40)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? AppTheme.accentTeal),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurface.withAlpha(80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadView(ThemeData theme) {
    final String title;
    final String subtitle;

    switch (_view) {
      case _ModalView.setupFirstPin:
        title = 'Create 4-Digit PIN';
        subtitle = 'Choose a memorable 4-digit code to lock LNote';
        break;
      case _ModalView.setupConfirmPin:
        title = 'Confirm your PIN';
        subtitle = 'Re-enter the 4-digit PIN to verify';
        break;
      case _ModalView.verifyCurrentForChange:
      case _ModalView.verifyCurrentForDisable:
        title = 'Enter Current PIN';
        subtitle = 'Verify your existing PIN to continue';
        break;
      case _ModalView.manage:
        title = '';
        subtitle = '';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (_view == _ModalView.setupConfirmPin) {
                    setState(() {
                      _view = _ModalView.setupFirstPin;
                      _enteredPin = '';
                      _errorMessage = null;
                    });
                  } else if (widget.storage.isAppLockEnabled) {
                    setState(() {
                      _view = _ModalView.manage;
                      _enteredPin = '';
                      _errorMessage = null;
                    });
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 48), // Balance close button
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // 4 Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final isFilled = i < _enteredPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? AppTheme.accentTeal : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? AppTheme.accentTeal : theme.colorScheme.onSurface.withAlpha(70),
                    width: 2,
                  ),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color: AppTheme.accentTeal.withAlpha(80),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            const SizedBox(height: 20),

          // Keypad 1-9
          Column(
            children: [
              _buildKeypadRow(['1', '2', '3'], theme),
              const SizedBox(height: 12),
              _buildKeypadRow(['4', '5', '6'], theme),
              const SizedBox(height: 12),
              _buildKeypadRow(['7', '8', '9'], theme),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Empty placeholder for symmetry
                  const SizedBox(width: 72, height: 56),
                  const SizedBox(width: 16),
                  _buildKeypadButton('0', theme),
                  const SizedBox(width: 16),
                  // Backspace
                  SizedBox(
                    width: 72,
                    height: 56,
                    child: IconButton(
                      onPressed: _onBackspace,
                      icon: const Icon(Icons.backspace_outlined),
                      color: theme.colorScheme.onSurface.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildKeypadButton(d, theme),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton(String digit, ThemeData theme) {
    return Container(
      width: 72,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(35),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
