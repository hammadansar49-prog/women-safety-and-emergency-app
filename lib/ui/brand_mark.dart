import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The SafeHer mark: a woman with long hair.
///
/// Drawn rather than shipped as an image so it stays sharp at any size and
/// takes its colours from the theme, which matters because the same mark sits
/// on blush, on berry and on ink. The launcher and notification icons are the
/// same geometry, kept in Android's own vector format.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.color, this.faceColor});

  /// Height of the mark. Its width is about 86% of this.
  final double size;

  /// The figure. Defaults to the app's berry.
  final Color? color;

  /// What shows through the face. This is an opening, not a fill, so it
  /// should be whatever the mark is sitting on.
  final Color? faceColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 0.84,
    height: size,
    child: CustomPaint(
      painter: _MarkPainter(
        color ?? AppColors.primary,
        faceColor ?? AppColors.bg,
      ),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color, this.faceColor);

  final Color color;
  final Color faceColor;

  /// The drawing's own box, which the paths below are written in.
  static const _left = 14.0;
  static const _top = 10.0;
  static const _height = 110.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _height;
    canvas.save();
    canvas.translate(-_left * scale, -_top * scale);
    canvas.scale(scale);

    final body = Paint()..color = color;
    final face = Paint()..color = faceColor;

    // Shoulders, drawn first so the hair falls over them.
    canvas.drawPath(
      Path()
        ..moveTo(60, 80)
        ..cubicTo(34, 80, 18, 96, 14, 120)
        ..lineTo(106, 120)
        ..cubicTo(102, 96, 86, 80, 60, 80)
        ..close(),
      body,
    );

    // Hair. Kept narrower than the shoulders on purpose: when it reaches as
    // wide as they are, the whole silhouette reads as a hood.
    canvas.drawPath(
      Path()
        ..moveTo(38, 110)
        ..cubicTo(28, 62, 34, 10, 60, 10)
        ..cubicTo(86, 10, 92, 62, 82, 110)
        ..cubicTo(78, 96, 72, 90, 68, 86)
        ..lineTo(52, 86)
        ..cubicTo(48, 90, 42, 96, 38, 110)
        ..close(),
      body,
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 50), width: 38, height: 48),
      face,
    );

    canvas.drawPath(
      Path()
        ..moveTo(60, 10)
        ..cubicTo(45, 10, 38, 24, 36, 44)
        ..cubicTo(43, 36, 52, 32, 60, 32)
        ..cubicTo(68, 32, 77, 36, 84, 44)
        ..cubicTo(82, 24, 75, 10, 60, 10)
        ..close(),
      body,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color || old.faceColor != faceColor;
}
