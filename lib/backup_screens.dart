import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/tokens.dart';
import 'ui/design.dart';

/// Shown once, right after backup is turned on. The code is the only way to
/// open the backup on another phone, and SafeHer cannot recover it.
class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({super.key, required this.code, required this.onDone});
  final String code;
  final VoidCallback onDone;

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  bool _saved = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: HeaderPage(
        headerHeight: 250,
        overlap: 20,
        bottomPadding: 40,
        animate: false,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Wordmark(),
            SizedBox(height: 18),
            HeaderTitle(
              'Your recovery code',
              subtitle: 'Keep it safe. It opens your account on a new phone.',
              size: 30,
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              widget.code,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedPill(
            label: _copied ? 'Copied' : 'Copy code',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: widget.code));
              if (mounted) setState(() => _copied = true);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Your chats and buddies are encrypted with a key only you hold. If you lose this code and your phone, SafeHer cannot bring them back.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _saved = !_saved),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Checkbox(
                    value: _saved,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _saved = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'I have saved my recovery code',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          BerryButton(label: 'Continue', onTap: _saved ? widget.onDone : null),
          if (!_saved) ...[
            const SizedBox(height: 8),
            Text(
              'Tick the box once you have saved the code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when this account already has a backup but this phone has no copy.
class RestoreBackupScreen extends StatefulWidget {
  const RestoreBackupScreen({
    super.key,
    required this.onRestore,
    required this.onStartOver,
  });

  /// Returns an error message, or null once the account has been restored.
  final Future<String?> Function(String code) onRestore;

  /// Gives up on the old backup and starts this account blank.
  final VoidCallback onStartOver;

  @override
  State<RestoreBackupScreen> createState() => _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends State<RestoreBackupScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy) return;
    if (_code.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length < 20) {
      setState(() => _error = 'Enter the 20 character recovery code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onRestore(_code.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _confirmStartOver() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start without your old data?'),
        content: const Text(
          'Your old chats and buddies stay locked in the backup and this account starts empty. A new recovery code replaces the old one, so the old data can no longer be opened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start empty'),
          ),
        ],
      ),
    );
    if (yes == true) widget.onStartOver();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: HeaderPage(
        headerHeight: 250,
        overlap: 20,
        bottomPadding: 40,
        animate: false,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Wordmark(),
            SizedBox(height: 18),
            HeaderTitle(
              'Welcome back',
              subtitle: 'Enter your recovery code to bring your account here.',
              size: 30,
            ),
          ],
        ),
        children: [
          DesignField(
            controller: _code,
            hint: 'XXXX-XXXX-XXXX-XXXX-XXXX',
            icon: Icons.key_outlined,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _go(),
            shadow: true,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 6),
          BerryButton(
            label: _busy ? 'Opening…' : 'Restore my account',
            busy: _busy,
            onTap: _go,
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _confirmStartOver,
              child: const Text('I lost my code'),
            ),
          ),
        ],
      ),
    );
  }
}
