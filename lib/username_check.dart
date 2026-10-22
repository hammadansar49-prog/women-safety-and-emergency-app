import 'dart:async';

import 'package:flutter/material.dart';

import 'theme/tokens.dart';

enum UsernameState { idle, invalid, checking, available, taken, unknown }

/// Live "is this username free?" while someone types.
///
/// [quick] is the offline Bloom filter hint: true means the name was free when
/// the filter was last built, so "available" shows at once. [confirm] is the
/// database answer that settles it a moment later (null when it cannot tell,
/// for example offline).
class UsernameChecker extends ChangeNotifier {
  UsernameChecker({this.quick, this.confirm});

  final bool? Function(String name)? quick;
  final Future<bool?> Function(String name)? confirm;

  static final pattern = RegExp(r'^[a-z0-9_]{3,20}$');

  UsernameState state = UsernameState.idle;
  String name = '';
  Timer? _timer;
  int _token = 0;

  void update(String raw) {
    name = raw.trim().toLowerCase();
    final token = ++_token;
    _timer?.cancel();
    if (name.isEmpty) {
      state = UsernameState.idle;
    } else if (!pattern.hasMatch(name)) {
      state = UsernameState.invalid;
    } else {
      state = quick?.call(name) == true
          ? UsernameState.available
          : UsernameState.checking;
      final check = confirm;
      if (check != null) {
        _timer = Timer(const Duration(milliseconds: 350), () async {
          bool? free;
          try {
            free = await check(name);
          } catch (_) {}
          if (token != _token) return;
          state = free == null
              ? (state == UsernameState.available
                    ? UsernameState.available
                    : UsernameState.unknown)
              : (free ? UsernameState.available : UsernameState.taken);
          notifyListeners();
        });
      }
    }
    notifyListeners();
  }

  bool get isTaken => state == UsernameState.taken;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// One line under the username field showing the checker's verdict.
class UsernameStatusLine extends StatelessWidget {
  const UsernameStatusLine({super.key, required this.checker});
  final UsernameChecker checker;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: checker,
    builder: (context, _) {
      final ok = AppColors.light ? const Color(0xFF1F6B45) : AppColors.success;
      final (text, color, icon) = switch (checker.state) {
        UsernameState.idle || UsernameState.unknown => (
          ' ',
          AppColors.textMuted,
          null,
        ),
        UsernameState.invalid => (
          'Use 3–20 letters, numbers or underscores.',
          AppColors.danger,
          Icons.error_outline_rounded,
        ),
        UsernameState.checking => (
          'Checking @${checker.name}…',
          AppColors.textMuted,
          Icons.hourglass_empty_rounded,
        ),
        UsernameState.available => (
          '@${checker.name} is available',
          ok,
          Icons.check_circle_outline_rounded,
        ),
        UsernameState.taken => (
          '@${checker.name} is already taken',
          AppColors.danger,
          Icons.cancel_outlined,
        ),
      };
      return Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
