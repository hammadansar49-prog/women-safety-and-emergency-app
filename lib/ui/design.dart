import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// The "SafeHer" wordmark: Space Grotesk, with "Her" picked out in the accent.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -size * 0.04,
      height: 1,
      color: AppColors.text,
    );
    return Text.rich(
      TextSpan(
        text: 'Safe',
        style: style,
        children: [
          TextSpan(
            text: 'Her',
            style: style.copyWith(
              color: AppColors.light
                  ? const Color(0xFFB01E52)
                  : AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// A deterministic avatar colour for a name, drawn from one warm family so a
/// row of buddies reads as a set rather than a rainbow.
Color avatarColor(String seed) {
  const light = [
    Color(0xFFC2255C),
    Color(0xFF7A4FA3),
    Color(0xFFB5532B),
    Color(0xFF6B2A55),
    Color(0xFF9A4A3F),
    Color(0xFF7C5568),
  ];
  const dark = [
    Color(0xFF6C6FB7),
    Color(0xFF8A55AC),
    Color(0xFF3F7F8C),
    Color(0xFFA0527A),
    Color(0xFF5E7BB5),
    Color(0xFF8C6FB0),
  ];
  final palette = AppColors.light ? light : dark;
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

/// Avatar colours in the design's order (berry, purple, terracotta).
Color avatarByIndex(int i) {
  const light = [Color(0xFFC2255C), Color(0xFF7A4FA3), Color(0xFFB5532B)];
  const dark = [Color(0xFF6C6FB7), Color(0xFF8A55AC), Color(0xFF3F7F8C)];
  return (AppColors.light ? light : dark)[i % 3];
}

/// A dashed rounded-rectangle outline, for "add" tiles.
class DashedBorder extends Decoration {
  const DashedBorder({required this.color, this.radius = 18, this.width = 1.5});
  final Color color;
  final double radius;
  final double width;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedPainter(this);
}

class _DashedPainter extends BoxPainter {
  _DashedPainter(this.d);
  final DashedBorder d;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size;
    if (size == null) return;
    final rect = (offset & size).deflate(d.width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(d.radius)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = d.width
      ..color = d.color;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + 6), paint);
        dist += 10;
      }
    }
  }
}

class AvatarDot extends StatelessWidget {
  const AvatarDot({
    super.key,
    required this.name,
    this.size = 42,
    this.child,
    this.color,
  });
  final String name;
  final Color? color;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color ?? avatarColor(name),
    ),
    child:
        child ??
        Text(
          name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
          ),
        ),
  );
}

/// The blush header with two slowly drifting orbs. It drops in on first build.
class BlushHeader extends StatefulWidget {
  const BlushHeader({
    super.key,
    required this.height,
    required this.child,
    this.bottomRadius = Radii.header,
    this.animate = true,
    this.lavenderTop,
  });

  /// Where the lavender orb sits from the top; null = near the bottom edge.
  final double? lavenderTop;

  /// Drop-in on first build. Off for tab pages so switching tabs is instant.
  final bool animate;

  /// Total header height (design value); content starts below the status bar.
  final double height;
  final double bottomRadius;
  final Widget child;

  @override
  State<BlushHeader> createState() => _BlushHeaderState();
}

class _BlushHeaderState extends State<BlushHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat(reverse: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context) && _drift.isAnimating) {
      _drift
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.top;
    final total = widget.height;
    final top = inset + 16 > 60 ? inset + 16 : 60.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: (reduceMotionOf(context) || !widget.animate)
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -22 * (1 - t)),
          child: child,
        ),
      ),
      child: SizedBox(
        height: total,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.header,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(widget.bottomRadius),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(widget.bottomRadius),
            ),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _drift,
                  builder: (context, _) {
                    final d = _drift.value;
                    return Stack(
                      children: [
                        Positioned(
                          right: -70 + 10 * d,
                          top: -40 + 12 * d,
                          child: _orb(220, AppColors.orbPeach, 0.7),
                        ),
                        Positioned(
                          right: 50 - 10 * d,
                          top: widget.lavenderTop == null
                              ? null
                              : widget.lavenderTop! + 12 * d,
                          bottom: widget.lavenderTop == null
                              ? 40 - 12 * d
                              : null,
                          child: _orb(70, AppColors.orbLavender, 0.8),
                        ),
                      ],
                    );
                  },
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, top, 24, 0),
                  child: widget.child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orb(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: opacity),
    ),
  );
}

/// A page made of a [BlushHeader] with a scrolling body whose first element can
/// overlap the header's bottom edge.
class HeaderPage extends StatelessWidget {
  const HeaderPage({
    super.key,
    required this.header,
    required this.headerHeight,
    required this.children,
    this.overlap = 34,
    this.bottomPadding = 120,
    this.maxWidth = 560,
    this.animate = true,
    this.lavenderTop,
    this.footer,
  });

  final double? lavenderTop;

  /// Pinned to the bottom of the page (e.g. "New to SafeHer? Create account").
  final Widget? footer;

  /// Stagger and drop-in on arrival. Tab pages turn this off.
  final bool animate;

  final Widget header;
  final double headerHeight;
  final double overlap;
  final double bottomPadding;
  final double maxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: BlushHeader(
            height: headerHeight,
            animate: animate,
            lavenderTop: lavenderTop,
            child: header,
          ),
        ),
        // The list starts where the body starts, so it never sits on top of
        // the header (which would swallow taps on the back button).
        Positioned(
          top: headerHeight - overlap,
          left: 0,
          right: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(22, 0, 22, bottomPadding),
                children: [
                  for (var i = 0; i < children.length; i++)
                    animate
                        ? EntranceFade(index: i, child: children[i])
                        : children[i],
                ],
              ),
            ),
          ),
        ),
        if (footer != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Center(child: footer),
          ),
      ],
    );
  }
}

/// Round back button for sub-screens that sit on a blush header.
class HeaderBack extends StatelessWidget {
  const HeaderBack({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.arrow_back_rounded, color: AppColors.text),
        ),
      ),
    ),
  );
}

/// Serif page title + muted subtitle, the way every header opens.
class HeaderTitle extends StatelessWidget {
  const HeaderTitle(this.title, {super.key, this.subtitle, this.size = 34});
  final String title;
  final String? subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: size,
            height: 1.1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.light
                  ? const Color(0xFF6A3A52)
                  : AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small uppercase section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8, left: 2),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        color: AppColors.onHeader,
      ),
    ),
  );
}

/// The solid berry call-to-action.
class BerryButton extends StatelessWidget {
  const BerryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Pressable(
    borderRadius: BorderRadius.circular(999),
    onTap: busy ? null : onTap,
    semanticLabel: label,
    child: Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.primary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Outlined secondary action.
class OutlinedPill extends StatelessWidget {
  const OutlinedPill({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
  });
  final String label;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Pressable(
    borderRadius: BorderRadius.circular(999),
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Text(
            label,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    ),
  );
}

/// A small rounded action chip used on rows ("Message", "Add buddy", ...).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onTap,
    this.filled = false,
    this.tone,
  });
  final String label;
  final VoidCallback? onTap;

  /// Solid berry when true, soft header tint otherwise.
  final bool filled;

  /// Optional fixed (background, foreground) override.
  final (Color, Color)? tone;

  @override
  Widget build(BuildContext context) {
    final bg = tone?.$1 ?? (filled ? AppColors.primary : AppColors.secondary);
    final fg = tone?.$2 ?? (filled ? Colors.white : AppColors.onHeader);
    return Pressable(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: bg,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

/// A rounded row card (icon chip, title, optional detail, trailing widget).
class RowCard extends StatelessWidget {
  const RowCard({
    super.key,
    required this.title,
    this.detail,
    this.leading,
    this.trailing,
    this.onTap,
  });
  final String title;
  final String? detail;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        hoverLift: 2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          detail!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded square icon chip used as a row leading.
class IconChip extends StatelessWidget {
  const IconChip(this.icon, {super.key, this.size = 40});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.32),
      color: AppColors.tint,
    ),
    child: Icon(icon, size: size * 0.5, color: AppColors.accent),
  );
}

/// A pill switch matching the design's toggles.
class SoftSwitch extends StatelessWidget {
  const SoftSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: Motion.standard,
        curve: Motion.enter,
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: value
              ? AppColors.primary
              : (AppColors.light
                    ? const Color(0xFFE7CBD3)
                    : AppColors.secondary),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 350),
          curve: Motion.spring,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Push route with a short fade, so moving between screens feels instant.
class SafeRoute<T> extends MaterialPageRoute<T> {
  SafeRoute({required super.builder, super.fullscreenDialog});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 140);
}

/// The design's input: a 58px rounded field with a leading icon, optional
/// reveal toggle, and a berry outline plus soft glow while focused.
class DesignField extends StatefulWidget {
  const DesignField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.prefixText,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.pill = false,
    this.shadow = false,
    this.accentBorder = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? prefixText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool pill;
  final bool shadow;
  final bool accentBorder;
  final Widget? trailing;

  @override
  State<DesignField> createState() => _DesignFieldState();
}

class _DesignFieldState extends State<DesignField> {
  final _focus = FocusNode();
  late bool _hidden = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.pill ? 999 : 18);
    final focused = _focus.hasFocus;
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    return AnimatedContainer(
      duration: Motion.standard,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: AppColors.surface,
        border: Border.all(
          color: focused || widget.accentBorder
              ? AppColors.primary
              : (widget.pill && AppColors.light
                    ? const Color(0xFFE7B9C7)
                    : AppColors.border),
          width: focused || widget.accentBorder ? 1.6 : 1,
        ),
        boxShadow: [
          if (focused)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              spreadRadius: 4,
            )
          else if (widget.shadow)
            const BoxShadow(
              color: Color(0x1A2E1426),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          if (widget.prefixText != null) ...[
            Text(
              widget.prefixText!,
              style: style?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: _hidden,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: widget.onSubmitted,
              onChanged: widget.onChanged,
              style: style,
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.hint,
                hintStyle: style?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
          if (widget.obscure)
            Semantics(
              button: true,
              label: _hidden ? 'Show password' : 'Hide password',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _hidden = !_hidden),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }
}
