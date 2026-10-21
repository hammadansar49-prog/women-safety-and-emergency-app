import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';

/// A four digit PIN pad: dots, a shake on a wrong PIN, and a number keypad.
/// [onComplete] gets the PIN once four digits are in and returns an error
/// message to shake and show, or null to accept it.
class PinEntry extends StatefulWidget {
  const PinEntry({
    super.key,
    required this.onComplete,
    this.message,
    this.disabled = false,
  });

  final Future<String?> Function(String pin) onComplete;
  final String? message;
  final bool disabled;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry>
    with SingleTickerProviderStateMixin {
  static const _length = 4;
  String _digits = '';
  String? _error;
  bool _checking = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _press(String digit) async {
    if (widget.disabled || _checking || _digits.length >= _length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _digits += digit;
      _error = null;
    });
    if (_digits.length < _length) return;
    _checking = true;
    final pin = _digits;
    final error = await widget.onComplete(pin);
    _checking = false;
    if (!mounted) return;
    if (error != null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = error);
      await _shake.forward(from: 0);
    }
    if (mounted) setState(() => _digits = '');
  }

  void _back() {
    if (_digits.isEmpty || _checking) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = _error ?? widget.message;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value),
              0,
            ),
            child: child,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _digits.length
                        ? (_error != null ? AppColors.danger : AppColors.primary)
                        : Colors.transparent,
                    border: Border.all(
                      color: i < _digits.length
                          ? (_error != null
                                ? AppColors.danger
                                : AppColors.primary)
                          : AppColors.border,
                      width: 1.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 20,
          child: Text(
            note ?? '',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _error != null ? AppColors.danger : null,
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final key in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _Key(
                      label: key,
                      enabled: !widget.disabled,
                      onTap: key == '<' ? _back : () => _press(key),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, required this.enabled});
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(width: 68, height: 68);
    return Semantics(
      button: true,
      label: label == '<' ? 'Delete' : label,
      child: Material(
        color: label == '<' ? Colors.transparent : AppColors.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: label == '<' ? Colors.transparent : AppColors.border,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 68,
            height: 68,
            child: Center(
              child: label == '<'
                  ? Icon(
                      Icons.backspace_outlined,
                      color: AppColors.textMuted,
                      size: 22,
                    )
                  : Text(
                      label,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown over the app when it opens (or returns after a while) for an account
/// that turned the PIN lock on. Five wrong tries pause the keypad for 30s.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    required this.social,
    required this.onUnlocked,
  });

  final SocialController social;
  final VoidCallback onUnlocked;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  int _misses = 0;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<String?> _check(String pin) async {
    if (widget.social.checkPin(pin)) {
      widget.onUnlocked();
      return null;
    }
    _misses++;
    if (_misses >= 5) {
      _misses = 0;
      setState(() => _cooldown = 30);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown--);
        if (_cooldown <= 0) t.cancel();
      });
      return 'Too many tries.';
    }
    return 'Wrong PIN. ${5 - _misses} ${5 - _misses == 1 ? 'try' : 'tries'} left.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.social.currentUser.name;
    // Opaque on purpose: it covers the app, so nothing underneath may show.
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          BlushHeader(
            height: 250,
            child: Column(
              children: [
                const Wordmark(),
                const SizedBox(height: 22),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.light ? Colors.white : AppColors.surface,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Welcome back, $name',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter your PIN to open SafeHer',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: PinEntry(
              onComplete: _check,
              disabled: _cooldown > 0,
              message: _cooldown > 0
                  ? 'Too many tries. Wait ${_cooldown}s.'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

enum PinMode { create, disable }

/// Turn the PIN lock on (choose + confirm a PIN) or off (confirm the current
/// one). The PIN is only ever stored salted and hashed, under this account.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.social, required this.mode});
  final SocialController social;
  final PinMode mode;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;

  bool get _creating => widget.mode == PinMode.create;

  String get _title => !_creating
      ? 'Turn off PIN lock'
      : (_first == null ? 'Choose a PIN' : 'Confirm your PIN');

  String get _subtitle => !_creating
      ? 'Enter your current PIN to turn it off.'
      : (_first == null
            ? 'Four digits. You will enter it when SafeHer opens.'
            : 'Enter the same four digits again.');

  Future<String?> _done(String pin) async {
    if (!_creating) {
      if (!widget.social.checkPin(pin)) return 'That is not your PIN.';
      widget.social.clearPin();
      if (mounted) Navigator.of(context).pop();
      return null;
    }
    if (_first == null) {
      setState(() => _first = pin);
      return null;
    }
    if (_first != pin) {
      setState(() => _first = null);
      return 'The PINs did not match. Start again.';
    }
    widget.social.setPin(pin);
    if (mounted) Navigator.of(context).pop();
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Column(
      children: [
        BlushHeader(
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HeaderBack(onTap: () => Navigator.of(context).maybePop()),
                ],
              ),
              const SizedBox(height: 14),
              HeaderTitle(_title, subtitle: _subtitle, size: 28),
            ],
          ),
        ),
        Expanded(child: PinEntry(key: ValueKey(_first), onComplete: _done)),
        const SizedBox(height: 16),
      ],
    ),
  );
}
