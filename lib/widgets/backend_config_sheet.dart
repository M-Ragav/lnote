import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class BackendConfigSheet extends StatefulWidget {
  final StorageService storage;

  const BackendConfigSheet({super.key, required this.storage});

  static Future<void> show(BuildContext context, StorageService storage) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BackendConfigSheet(storage: storage),
    );
  }

  @override
  State<BackendConfigSheet> createState() => _BackendConfigSheetState();
}

class _BackendConfigSheetState extends State<BackendConfigSheet> {
  late TextEditingController _controller;
  bool _isTesting = false;
  HealthResult? _testResult;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.storage.backendUrl ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _testResult = const HealthResult(isOk: false, error: 'Please enter a backend URL');
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final result = await SyncService.checkHealth(text);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result;
      });
    }
  }

  Future<void> _saveAndSync() async {
    final text = _controller.text.trim();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await widget.storage.setBackendUrl(text.isEmpty ? null : text);

    if (!mounted) return;
    nav.pop();

    if (text.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Backend connected & syncing in background...'),
            ],
          ),
          backgroundColor: AppTheme.accentTeal,
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _controller.text = data.text!.trim();
        _testResult = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(50),
          width: 0.5,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: Colors.black,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backend Server',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Sync sessions across Laptop & Mobile devices',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Presets
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Laptop (Localhost)'),
                avatar: const Icon(Icons.laptop_rounded, size: 16),
                onPressed: () {
                  setState(() {
                    _controller.text = 'http://127.0.0.1:8000';
                    _testResult = null;
                  });
                },
              ),
              ActionChip(
                label: const Text('Mobile (Wi-Fi LAN)'),
                avatar: const Icon(Icons.phone_android_rounded, size: 16),
                onPressed: () {
                  setState(() {
                    _controller.text = 'http://192.168.1.7:8000';
                    _testResult = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // URL Input
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Backend URL',
              hintText: 'http://192.168.1.7:8000',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() {
                        _controller.clear();
                        _testResult = null;
                      }),
                    ),
                  IconButton(
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    tooltip: 'Paste',
                    onPressed: _pasteFromClipboard,
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) {
              if (_testResult != null) setState(() => _testResult = null);
            },
          ),
          const SizedBox(height: 12),

          // Test Connection button
          OutlinedButton.icon(
            onPressed: _isTesting ? null : _testConnection,
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check_rounded, size: 18),
            label: Text(_isTesting ? 'Testing connection...' : 'Test Connection'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Test result banner
          if (_testResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testResult!.isOk
                    ? AppTheme.accentTeal.withAlpha(25)
                    : AppTheme.errorRed.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _testResult!.isOk
                      ? AppTheme.accentTeal.withAlpha(80)
                      : AppTheme.errorRed.withAlpha(80),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _testResult!.isOk
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: _testResult!.isOk ? AppTheme.accentTeal : AppTheme.errorRed,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _testResult!.isOk
                              ? 'Server Online (${_testResult!.latency?.inMilliseconds}ms)'
                              : 'Connection Failed',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _testResult!.isOk
                                ? AppTheme.accentTeal
                                : AppTheme.errorRed,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _testResult!.isOk
                              ? 'Server v${_testResult!.version} • ${_testResult!.totalDays} days • ${_testResult!.totalSessions} sessions stored'
                              : (_testResult!.error ?? 'Unknown error'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Action Buttons
          Row(
            children: [
              if (widget.storage.isBackendConfigured) ...[
                Expanded(
                  flex: 1,
                  child: TextButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await widget.storage.setBackendUrl(null);
                      if (mounted) nav.pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Disconnect'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _saveAndSync,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save & Sync Now',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
