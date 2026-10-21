import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A frosted, hairline-edged surface.
///
/// Rules this enforces (from `.tastemaker/style-lock.md`):
/// - Glass is for **elevated** surfaces only — nav, cards, sheets, dialogs.
///   Never put long body text directly on glass; contrast is not reliable over
///   a moving backdrop.
/// - The 1px hairline at ~12% white is what actually makes a panel read as a
///   pane of glass rather than a translucent rectangle.
/// - Depth comes from blur + hairline + (optional) glow, not drop shadows.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.x6),
    this.borderRadius = Radii.brMd,
    this.blur = 22,
    this.opacity = 0.62,
    this.glow,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final double opacity;

  /// Optional bloom behind the panel. Reserved for surfaces that genuinely
  /// carry state (the SOS panel, a focused field) — not decoration on
  /// every card, which is how a glow system stops meaning anything.
  final Color? glow;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final panel = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: AppColors.surface.withValues(alpha: opacity),
            border: Border.all(
              color: borderColor ?? AppColors.glassHairline,
              width: 1,
            ),
            // A faint top-down sheen: light catches the top edge of real glass.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (glow == null) return panel;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: glow!.withValues(alpha: 0.28),
            blurRadius: 36,
            spreadRadius: -6,
          ),
        ],
      ),
      child: panel,
    );
  }
}
