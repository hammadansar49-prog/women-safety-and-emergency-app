import 'package:flutter/material.dart';

import 'theme/tokens.dart';
import 'ui/design.dart';

/// The first-run guide: three short animated steps that teach the slider, the
/// SOS buddies and the volume-key shortcut. It has no skip button on purpose;
/// an SOS app should be understood before it is relied on.
class OnboardingGuide extends StatefulWidget {
  const OnboardingGuide({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingGuide> createState() => _OnboardingGuideState();
}

class _OnboardingGuideState extends State<OnboardingGuide>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  int _index = 0;

  static const _steps = <({String title, String body})>[
    (
      title: 'Slide to send an SOS',
      body:
          'Drag the SOS button across when you need help. A short countdown gives you time to cancel by mistake.',
    ),
    (
      title: 'Choose your SOS buddies',
      body:
          'Pick up to five friends. They must approve first, and only they can ever receive your alert.',
    ),
    (
      title: 'Use the volume key',
      body:
          'Press your volume key twice, even with the phone in your pocket. Do the same again to quietly stop it.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _steps.length - 1) {
      widget.onDone();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _index == _steps.length - 1;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          BlushHeader(
            height: 360,
            bottomRadius: 44,
            child: Column(
              children: [
                const Wordmark(),
                const SizedBox(height: 18),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [
                      _SlideIllustration(animation: _loop),
                      _BuddiesIllustration(animation: _loop),
                      _KeyIllustration(animation: _loop),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Column(
                      key: ValueKey(_index),
                      children: [
                        Text(
                          _steps[_index].title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _steps[_index].body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _steps.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: i == _index
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  BerryButton(label: last ? 'Get started' : 'Next', onTap: _next),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color get _card => AppColors.light ? Colors.white : AppColors.surface;

/// A knob sliding along a track.
class _SlideIllustration extends StatelessWidget {
  const _SlideIllustration({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(
          (animation.value * 1.25).clamp(0.0, 1.0),
        );
        return Container(
          width: 280,
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: _card,
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Opacity(
                  opacity: 1 - t,
                  child: Text(
                    'Slide to send SOS',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (280 - 12 - 60) * t,
                child: Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Buddy avatars popping in one after another.
class _BuddiesIllustration extends StatelessWidget {
  const _BuddiesIllustration({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++)
            Builder(
              builder: (context) {
                final s = ((animation.value * 1.4 - i * 0.18).clamp(0.0, 1.0));
                final pop = Curves.elasticOut.transform(s);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Transform.scale(
                    scale: pop,
                    child: i == 3
                        ? Container(
                            width: 58,
                            height: 58,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _card,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(Icons.add, color: AppColors.primary),
                          )
                        : AvatarDot(
                            name: const ['A', 'S', 'M'][i],
                            size: 58,
                            color: avatarByIndex(i),
                          ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

/// A phone edge with a volume key that pulses twice.
class _KeyIllustration extends StatelessWidget {
  const _KeyIllustration({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        double pulse(double at) {
          final d = (animation.value - at).abs();
          return (1 - d / 0.1).clamp(0.0, 1.0);
        }

        final p = pulse(0.25) > pulse(0.5) ? pulse(0.25) : pulse(0.5);
        return SizedBox(
          width: 220,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: _card,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
              Positioned(
                right: 40,
                top: 46,
                child: Container(
                  width: 8,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Color.lerp(
                      AppColors.border,
                      AppColors.primary,
                      p,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                top: 52 - 10 * p,
                child: Opacity(
                  opacity: p,
                  child: Icon(
                    Icons.keyboard_double_arrow_left_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
