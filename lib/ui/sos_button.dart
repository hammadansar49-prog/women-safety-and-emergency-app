import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../emergency_controller.dart';
import '../theme/tokens.dart';
import 'motion.dart';

/// The one control this whole product exists for.
///
/// It is deliberately the largest, highest-contrast thing on the home surface:
/// the safety-app research lane is consistent that the panic control must be a
/// single large target reachable in one tap, not an item in a menu.
///
/// Motion is state-bound, which is the gate every animation here has to pass:
/// - **idle** — a slow, low-amplitude breath. Signals "armed and ready" without
///   demanding attention during the 99% of the time nothing is wrong.
/// - **countdown** — a sweeping ring draining to zero, so the remaining time is
///   readable at a glance instead of only as a number.
/// - **active** — a hard red pulse. This is the only element in the app allowed
///   to animate continuously, and only while an SOS is live.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.status,
    required this.remaining,
    required this.countdownSeconds,
    required this.onTap,
    this.enabled = true,
  });

  final EmergencyStatus status;
  final int remaining;
  final int countdownSeconds;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.pulse,
  )..repeat(reverse: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context) && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isActive => widget.status == EmergencyStatus.active;
  bool get _isCountdown => widget.status == EmergencyStatus.countdown;

  String get _label => switch (widget.status) {
    EmergencyStatus.idle => 'SOS',
    EmergencyStatus.countdown => '${widget.remaining}',
    EmergencyStatus.active => 'ACTIVE',
  };

  String get _caption => switch (widget.status) {
    EmergencyStatus.idle => 'Hold the moment it matters',
    EmergencyStatus.countdown => 'Tap to cancel',
    EmergencyStatus.active => 'Help is being alerted',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduce = reduceMotionOf(context);
    // Idle breathes gently; active pulses hard enough to read across a room.
    final amplitude = _isActive ? 0.055 : 0.018;
    final ringColor = _isActive || _isCountdown
        ? AppColors.danger
        : AppColors.accent;

    return Semantics(
      button: true,
      label: _isActive
          ? 'SOS is active. Activate to stop.'
          : _isCountdown
          ? 'SOS starts in ${widget.remaining} seconds. Activate to cancel.'
          : 'Send SOS',
      child: Pressable(
        onTap: widget.enabled ? widget.onTap : null,
        enabled: widget.enabled,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        glow: ringColor,
        pressScale: 0.94,
        hoverLift: 3,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final wave = reduce ? 0.5 : _controller.value;
            final scale = 1 + amplitude * wave;
            return SizedBox(
              width: 252,
              height: 252,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer bloom — grows with the pulse so the glow feels like
                  // it is radiating from the button, not painted behind it.
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ringColor.withValues(
                              alpha: _isActive ? 0.40 : 0.22,
                            ),
                            blurRadius: _isActive ? 64 : 42,
                            spreadRadius: _isActive ? 6 : -4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Countdown ring / idle halo.
                  SizedBox(
                    width: 236,
                    height: 236,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: _isCountdown && widget.countdownSeconds > 0
                            ? widget.remaining / widget.countdownSeconds
                            : 1,
                        color: ringColor,
                        showProgress: _isCountdown,
                        pulse: _isActive ? wave : 0,
                      ),
                    ),
                  ),
                  Transform.scale(scale: scale, child: child),
                ],
              ),
            );
          },
          child: Container(
            width: 196,
            height: 196,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isActive || _isCountdown
                    ? [Color(0xFFFF6B85), AppColors.danger]
                    : [AppColors.accent, AppColors.primary],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _label,
                  // Large + bold is a hard requirement, not a style choice:
                  // white on the danger red is 3.21:1, which is UI-safe only.
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontSize: _isCountdown ? 64 : 42,
                    letterSpacing: _isCountdown ? -2 : 2,
                  ),
                ),
                const SizedBox(height: Space.x1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                  child: Text(
                    _caption,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.showProgress,
    required this.pulse,
  });

  final double progress;
  final Color color;
  final bool showProgress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withValues(alpha: 0.16 + 0.14 * pulse);
    canvas.drawCircle(center, radius, track);

    if (!showProgress) return;
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      sweep,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.showProgress != showProgress ||
      old.pulse != pulse;
}
