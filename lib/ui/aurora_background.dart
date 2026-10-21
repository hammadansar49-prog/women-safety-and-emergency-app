import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The living backdrop every glass surface sits on.
///
/// Glass only reads as glass when there is something behind it worth blurring;
/// a frosted panel over a flat fill just looks grey. This paints a few large,
/// softly-blurred violet/magenta orbs that drift on slow, offset sine paths, so
/// the blur always has real gradient content underneath.
///
/// It is deliberately cheap: three orbs, painted as blurred radial gradients in
/// a single `CustomPaint`, with no per-frame widget rebuilds.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.aurora,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the OS "reduce motion" setting: the field still renders, it just
    // stops drifting. Ambient motion is the first thing that should go.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0.18; // a composed-looking frame, not the loop seam
    } else if (!reduceMotion && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.bg),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _AuroraPainter(_controller.value),
                ),
              ),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _Orb {
  const _Orb({
    required this.color,
    required this.anchor,
    required this.drift,
    required this.radiusFactor,
    required this.phase,
  });

  final Color color;
  final Alignment anchor;
  final Offset drift;
  final double radiusFactor;
  final double phase;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t);

  final double t;

  // Violet -> magenta, straight off the locked palette. Opacities stay low:
  // this is atmosphere, not a feature, and the text above it must stay legible.
  static const _orbs = <_Orb>[
    _Orb(
      color: AppColors.primary,
      anchor: Alignment(-0.75, -0.85),
      drift: Offset(0.22, 0.16),
      radiusFactor: 0.78,
      phase: 0,
    ),
    _Orb(
      color: AppColors.accent,
      anchor: Alignment(0.9, -0.35),
      drift: Offset(-0.18, 0.24),
      radiusFactor: 0.62,
      phase: 0.37,
    ),
    _Orb(
      color: AppColors.secondary,
      anchor: Alignment(-0.2, 0.95),
      drift: Offset(0.26, -0.14),
      radiusFactor: 0.9,
      phase: 0.68,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    for (final orb in _orbs) {
      final angle = (t + orb.phase) * 2 * math.pi;
      final dx = math.cos(angle) * orb.drift.dx * shortest;
      final dy = math.sin(angle) * orb.drift.dy * shortest;

      final center =
          Offset(
            (orb.anchor.x + 1) / 2 * size.width,
            (orb.anchor.y + 1) / 2 * size.height,
          ) +
          Offset(dx, dy);
      final radius = shortest * orb.radiusFactor;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withValues(alpha: 0.42),
            orb.color.withValues(alpha: 0.14),
            orb.color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * 0.08);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.t != t;
}
