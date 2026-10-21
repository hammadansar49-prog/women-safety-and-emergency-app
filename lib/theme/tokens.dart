import 'package:flutter/widgets.dart';

/// The single source of truth for SafeHer's visual tokens.
///
/// Every value here is recorded in `.tastemaker/style-lock.md`. Widgets must
/// read from here (or from `Theme.of(context)`, which is built from these)
/// rather than writing raw hex or magic spacing numbers inline — that drift is
/// what makes a UI stop looking like one system.
class AppColors {
  const AppColors._();

  // Generated palette: premium / dark / analogous (seed 23), violet -> magenta.
  static const text = Color(0xFFEFF1FE);
  static const bg = Color(0xFF0B0C11);
  static const surface = Color(0xFF16171D);
  static const primary = Color(0xFF6C6FB7);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF2A2C41);
  static const accent = Color(0xFFB68AD0);
  static const border = Color(0xFF222229);

  /// Reserved exclusively for the active-SOS state. Never used as a generic
  /// accent — an emergency has to look unlike anything else in the product.
  /// 6.08:1 on [bg]. White labels on this fill are UI-safe only (3.21:1), so
  /// they are permitted at large bold sizes and nowhere else.
  static const danger = Color(0xFFFF4D6D);

  /// Muted body text. Derived from [text], kept here so the dimmed tone is one
  /// value instead of a dozen hand-picked opacities.
  static const textMuted = Color(0xFF9BA0B8);

  /// Hairline that makes a glass panel read as glass: ~12% white.
  static const glassHairline = Color(0x1FFFFFFF);
}

/// 4px base spacing scale. Named steps with roles, not arbitrary numbers.
class Space {
  const Space._();
  static const x1 = 4.0; // hairline gaps: icon-to-label
  static const x2 = 8.0; // tightly related elements
  static const x3 = 12.0; // dense nav/list row floor
  static const x4 = 16.0; // standard component padding
  static const x6 = 24.0; // content card internal padding (minimum)
  static const x8 = 32.0; // cards carrying real weight
  static const x12 = 48.0; // major element separation
  static const x16 = 64.0; // screen-level breathing room
}

/// Corner radii. Four steps only — mixed radii read as unintentional.
class Radii {
  const Radii._();
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;

  static const brSm = BorderRadius.all(Radius.circular(sm));
  static const brMd = BorderRadius.all(Radius.circular(md));
  static const brLg = BorderRadius.all(Radius.circular(lg));
}

/// Motion budget. Durations and curves live here so no widget invents its own
/// timing — inconsistent easing is the fastest way for motion to feel cheap.
class Motion {
  const Motion._();

  static const micro = Duration(milliseconds: 120); // press, hover
  static const standard = Duration(milliseconds: 220); // state change
  static const entrance = Duration(milliseconds: 320); // first appearance
  static const page = Duration(milliseconds: 360); // route transition
  static const aurora = Duration(seconds: 12); // ambient background loop
  static const pulse = Duration(milliseconds: 1400); // active SOS heartbeat

  /// Entrances and most UI motion. Never `easeIn` on UI — it feels sluggish
  /// because the slow part is at the start, where the user is waiting.
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// Press-release overshoot. Clamped so it reads springy, not bouncy.
  static const spring = Curves.easeOutBack;

  /// Stagger step for list entrances.
  static const stagger = Duration(milliseconds: 45);
}
