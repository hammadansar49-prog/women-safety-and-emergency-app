import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../emergency_controller.dart';
import '../theme/tokens.dart';
import 'design.dart';
import 'motion.dart';

/// "Slide to send alert". Drag the knob to the end, or tap it (so it stays
/// reachable without a precise swipe). Springs back if released early.
class SlideToSos extends StatefulWidget {
  const SlideToSos({
    super.key,
    required this.onComplete,
    required this.idle,
    this.label = 'Slide to send alert',
  });

  final VoidCallback onComplete;

  /// True while no SOS is running. When it flips back to true the slider
  /// returns to the start.
  final bool idle;
  final String label;

  @override
  State<SlideToSos> createState() => _SlideToSosState();
}

class _SlideToSosState extends State<SlideToSos> {
  static const _knob = 58.0;
  static const _pad = 6.0;
  double _drag = 0;
  bool _dragging = false;
  bool _done = false;

  @override
  void didUpdateWidget(SlideToSos old) {
    super.didUpdateWidget(old);
    if (widget.idle && !old.idle) {
      setState(() {
        _drag = 0;
        _done = false;
      });
    }
  }

  void _complete(double travel) {
    if (_done) return;
    setState(() {
      _done = true;
      _dragging = false;
      _drag = travel;
    });
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      widget.onComplete();
      // If nothing started (e.g. no SOS buddies yet), spring back.
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted && widget.idle) {
          setState(() {
            _drag = 0;
            _done = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final travel = math.max(1.0, box.maxWidth - 3 - _pad * 2 - _knob);
        final duration = _dragging || reduce
            ? Duration.zero
            : const Duration(milliseconds: 480);
        final shadow = AppColors.text;
        return Container(
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppColors.surface,
            border: Border.all(color: AppColors.text, width: 1.5),
            boxShadow: [BoxShadow(color: shadow, offset: const Offset(4, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: duration,
                  curve: Motion.enter,
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _drag + _knob + _pad * 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: (1 - _drag / (travel * 0.55)).clamp(0.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsets.only(left: _knob),
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeOutBack,
                  left: _pad + _drag,
                  top: 6,
                  child: Semantics(
                    button: true,
                    label: 'Slide to send SOS',
                    child: GestureDetector(
                      onTap: () => _complete(travel),
                      onHorizontalDragStart: (_) =>
                          setState(() => _dragging = true),
                      onHorizontalDragUpdate: (d) => setState(
                        () => _drag = (_drag + d.delta.dx).clamp(0.0, travel),
                      ),
                      onHorizontalDragEnd: (_) {
                        if (_drag >= travel * 0.85) {
                          _complete(travel);
                        } else {
                          setState(() {
                            _dragging = false;
                            _drag = 0;
                          });
                        }
                      },
                      child: Container(
                        width: _knob,
                        height: _knob,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: const Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The popup that rises over the whole app while an SOS is counting down or
/// active: a draining ring with the seconds left, then the live state.
class SosSheet extends StatefulWidget {
  const SosSheet({
    super.key,
    required this.status,
    required this.remaining,
    required this.total,
    required this.recipients,
    required this.onCancel,
    required this.onSafe,
  });

  final EmergencyStatus status;
  final int remaining;
  final int total;
  final List<String> recipients;
  final VoidCallback onCancel;
  final VoidCallback onSafe;

  @override
  State<SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<SosSheet> {
  EmergencyStatus _shown = EmergencyStatus.countdown;

  @override
  void didUpdateWidget(SosSheet old) {
    super.didUpdateWidget(old);
    if (widget.status != EmergencyStatus.idle) _shown = widget.status;
  }

  @override
  void initState() {
    super.initState();
    if (widget.status != EmergencyStatus.idle) _shown = widget.status;
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.status != EmergencyStatus.idle;
    final reduce = reduceMotionOf(context);
    final slide = reduce ? Duration.zero : const Duration(milliseconds: 600);
    return IgnorePointer(
      ignoring: !open,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                opacity: open ? 1 : 0,
                child: const ColoredBox(color: Color(0x80351626)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                duration: slide,
                curve: Curves.easeOutCubic,
                offset: Offset(0, open ? 0 : 1.05),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 560),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    28 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(36),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x40351626), blurRadius: 40),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.94, end: 1.0).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _shown == EmergencyStatus.countdown
                            ? _Countdown(
                                key: const ValueKey('count'),
                                remaining: widget.remaining,
                                total: widget.total,
                                count: widget.recipients.length,
                                onCancel: widget.onCancel,
                              )
                            : _Active(
                                key: const ValueKey('active'),
                                recipients: widget.recipients,
                                onSafe: widget.onSafe,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({
    super.key,
    required this.remaining,
    required this.total,
    required this.count,
    required this.onCancel,
  });
  final int remaining;
  final int total;
  final int count;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SOS STARTING',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.onHeader,
          ),
        ),
        const SizedBox(height: 6),
        Text('Sending your alert', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 22),
        SizedBox(
          width: 170,
          height: 170,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: target),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.linear,
            builder: (context, value, _) => CustomPaint(
              painter: _RingPainter(value),
              child: Center(
                child: Text(
                  '$remaining',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 72,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          count == 0
              ? 'Pick SOS buddies first so someone can receive it.'
              : 'Your $count SOS ${count == 1 ? 'buddy gets' : 'buddies get'} your live location when the timer ends.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        OutlinedPill(label: 'Cancel', onTap: onCancel),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = AppColors.surface);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = AppColors.border;
    canvas.drawCircle(c, r, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _Active extends StatelessWidget {
  const _Active({super.key, required this.recipients, required this.onSafe});
  final List<String> recipients;
  final VoidCallback onSafe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('SOS is active', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Your live location is being tracked on this phone. It reaches your buddies once cloud delivery is switched on.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (recipients.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 10,
            children: [
              for (var i = 0; i < recipients.length; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 450 + i * 120),
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) => Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.scale(scale: 0.4 + 0.6 * v, child: child),
                  ),
                  child: Column(
                    children: [
                      AvatarDot(name: recipients[i], size: 46),
                      const SizedBox(height: 6),
                      Text(
                        recipients[i],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        Pressable(
          borderRadius: BorderRadius.circular(999),
          onTap: onSafe,
          semanticLabel: 'I am safe, end SOS',
          child: Container(
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: AppColors.light ? const Color(0xFF35162B) : AppColors.text,
            ),
            child: Text(
              'I am safe · End SOS',
              style: TextStyle(
                color: AppColors.light ? const Color(0xFFFFF7F3) : AppColors.bg,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
