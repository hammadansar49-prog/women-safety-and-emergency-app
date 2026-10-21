import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Whether the platform asked us to cut motion. Every animated widget in the
/// app routes through this rather than checking the flag ad hoc.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Press + hover feedback for any tappable surface.
///
/// - **Press**: scales down on the way in, releases with a clamped overshoot so
///   it reads springy rather than mechanical.
/// - **Hover**: pointer-gated by construction — `MouseRegion` only fires for a
///   real pointer, so touch devices never get stuck in a hover state. Lifts the
///   surface slightly and blooms a glow.
///
/// Only scale/translate/opacity are animated; nothing here animates a layout
/// property, so it stays on the compositor.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = Radii.brMd,
    this.glow,
    this.hoverLift = 2.0,
    this.pressScale = 0.97,
    this.enabled = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  /// Hover bloom colour. Defaults to the accent.
  final Color? glow;
  final double hoverLift;
  final double pressScale;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final interactive = widget.enabled && widget.onTap != null;
    final glow = widget.glow ?? AppColors.accent;

    final lift = (_hovered && !_pressed && !reduce) ? -widget.hoverLift : 0.0;
    final scale = _pressed && !reduce ? widget.pressScale : 1.0;

    Widget content = AnimatedScale(
      scale: scale,
      duration: Motion.micro,
      // Overshoot only on release; pressing in should feel immediate.
      curve: _pressed ? Curves.easeOut : Motion.spring,
      child: AnimatedContainer(
        duration: Motion.standard,
        curve: Motion.enter,
        transform: Matrix4.translationValues(0, lift, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _hovered && interactive && !reduce
              ? [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.30),
                    blurRadius: 28,
                    spreadRadius: -8,
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );

    if (widget.semanticLabel != null) {
      content = Semantics(
        label: widget.semanticLabel,
        button: true,
        enabled: interactive,
        child: content,
      );
    }

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: interactive
            ? () => setState(() => _pressed = false)
            : null,
        child: content,
      ),
    );
  }
}

/// Fade-and-rise entrance, offset by [index] so a list arrives as a stagger
/// rather than all at once. Runs on first build only — this is an arrival
/// animation, not a state animation, so it must not replay on rebuild.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 14,
  });

  final Widget child;
  final int index;
  final double offsetY;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotionOf(context)) {
      _controller.value = 1;
      return;
    }
    // Cap the stagger so a long list never leaves the last row waiting.
    final delay = Motion.stagger * widget.index.clamp(0, 10);
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Motion.enter);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - curved.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
