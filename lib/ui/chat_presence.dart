import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'motion.dart';

/// A shared frame ticker, scoped to the small live status area.
class ChatPresenceIndicator extends StatefulWidget {
  const ChatPresenceIndicator({
    super.key,
    required this.online,
    required this.reading,
    required this.typing,
    required this.label,
  });
  final bool online, reading, typing;
  final String label;
  @override
  State<ChatPresenceIndicator> createState() => _ChatPresenceIndicatorState();
}

class _ChatPresenceIndicatorState extends State<ChatPresenceIndicator>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  void _sync() {
    final animate =
        !reduceMotionOf(context) && (widget.reading || widget.typing);
    if (animate && !_pulse.isAnimating) _pulse.repeat();
    if (!animate) _pulse.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ChatPresenceIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) {
      final glow = (math.sin(_pulse.value * math.pi * 2) + 1) / 2;
      return Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.online ? AppColors.success : AppColors.textMuted,
              boxShadow: widget.reading
                  ? [
                      BoxShadow(
                        color: AppColors.success.withValues(
                          alpha: 0.35 + glow * 0.45,
                        ),
                        blurRadius: 4 + glow * 5,
                        spreadRadius: glow * 2,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              widget.typing ? 'typing…' : widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: widget.online ? AppColors.success : null,
              ),
            ),
          ),
          if (widget.typing) ...[
            const SizedBox(width: 4),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Opacity(
                  opacity:
                      0.35 +
                      0.65 *
                          ((math.sin((_pulse.value - i * 0.18) * math.pi * 2) +
                                  1) /
                              2),
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );
}
