import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// The card that stands for one SOS in Activity: a small stylised map with the
/// pin where it ended, the headline, and a status badge.
///
/// The map is drawn, not fetched — Activity is a glance, and a real tile
/// request would put the person's history on someone else's server. Tapping it
/// opens the actual map.
class SosMapCard extends StatelessWidget {
  const SosMapCard({
    super.key,
    required this.title,
    required this.detail,
    required this.badge,
    required this.resolved,
    this.onTap,
  });

  final String title;
  final String detail;
  final String badge;

  /// A finished SOS gets the calm green badge; a running one the berry.
  final bool resolved;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _MapPainter()),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: resolved ? AppColors.successTint : AppColors.tint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: resolved ? AppColors.success : AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Pressable(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap!,
      semanticLabel: '$title. $detail. Open the map.',
      child: card,
    );
  }
}

/// Two broad roads, the walked path as a dotted line, and the pin — the shapes
/// from the locked design, scaled to whatever width the card gets.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    double x(double v) => v / 320 * w;
    double y(double v) => v / 120 * h;

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.tint);

    final road = Paint()
      ..color = AppColors.mapRoad
      ..style = PaintingStyle.stroke
      ..strokeWidth = y(10);
    canvas.drawLine(Offset(x(-10), y(30)), Offset(x(330), y(70)), road);
    canvas.drawLine(
      Offset(x(110), y(-10)),
      Offset(x(170), y(130)),
      road..strokeWidth = y(8),
    );

    // The dotted track, drawn as evenly spaced dots along the curve.
    final path = Path()
      ..moveTo(x(0), y(90))
      ..cubicTo(x(60), y(80), x(90), y(30), x(150), y(50))
      ..cubicTo(x(210), y(70), x(250), y(100), x(320), y(40));
    final dot = Paint()..color = AppColors.mapTrack;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += x(9)) {
        final p = metric.getTangentForOffset(d)?.position;
        if (p != null) canvas.drawCircle(p, y(1.6), dot);
      }
    }

    // The pin: a teardrop with a white eye, where the SOS ended.
    final pin = Paint()..color = AppColors.primary;
    final c = Offset(x(243), y(45));
    final r = y(15);
    canvas.drawCircle(c, r, pin);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.72, c.dy + r * 0.72)
        ..lineTo(c.dx + r * 0.1, c.dy + r * 1.5)
        ..lineTo(c.dx + r * 0.72, c.dy + r * 0.72)
        ..close(),
      pin,
    );
    canvas.drawCircle(c, r * 0.42, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(_MapPainter old) => false;
}
