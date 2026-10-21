# Style lock — SafeHer

Established: 2026-10-21
Stack: Flutter (Dart), targets Android + Flutter web. Tokens live in `lib/theme/tokens.dart`; `ThemeData` is built in `lib/theme/app_theme.dart`. Widgets read `Theme.of(context)` / `AppTokens`, never raw hex.
Mood: Premium / confident, dark mode.
Aesthetic lane: dark aurora-glass with violet neon focus glow (an aesthetic lane, not an official design system).

## Color contract

Generated with `scripts/generate_palette.py --mood premium --mode dark --seed 23`
(analogous harmony, base hue 280.7, accent hue 312.7 — violet to magenta, which matches both the existing purple shield brand and the user's requested neon direction).

| Role | Hex |
|---|---|
| text | `#EFF1FE` |
| bg | `#0B0C11` |
| surface | `#16171D` |
| primary | `#6C6FB7` |
| on-primary | `#FFFFFF` |
| secondary | `#2A2C41` |
| accent | `#B68AD0` |
| border | `#222229` |

**Legal pairings (verified, do not improvise new ones):**
- Text-safe (>=4.5, body text / labels on a fill): bg/on-primary, surface/on-primary, text/bg, text/surface, border/on-primary, text/border, bg/accent, surface/accent, accent/border, primary/on-primary
- UI-safe (>=3.0, large text, icons, state borders): bg/primary, text/primary, surface/primary, primary/border
- Decorative (<3.0, hairlines only, never the sole carrier of state): accent/on-primary, text/accent, primary/accent, bg/border, surface/border, text/on-primary, bg/surface

Any new pairing must be re-checked with `check_contrast.py --matrix` and recorded here before shipping.

### Danger / SOS color
`#FF4D6D` is reserved **exclusively** for the active-SOS state (button fill, pulse, active banner). It is outside the generated palette on purpose: an emergency state must not read as "just another accent."

Verified with `check_contrast.py` on 2026-10-21:
- `#FF4D6D` on bg `#0B0C11` — **6.08:1**, text-safe.
- `#FF4D6D` on surface `#16171D` — **5.56:1**, text-safe.
- `#FFFFFF` on `#FF4D6D` — **3.21:1**, UI-safe only (fails the 4.5 body-text floor). So white-on-red is permitted **only** at large bold sizes (>=18.66px bold / >=24px regular), which is exactly the SOS button label and nothing else. Small text never sits on the red fill.

## Dark mode
Locked dark. The user chose the dark direction over a dark+light toggle. The existing `appearance` setting is kept so nothing breaks, but light and dark both resolve to this one dark theme for now; a light variant would need its own generated companion palette from the same seed.

## Type
- Display / headings: **Space Grotesk** (geometric, slightly technical — carries the "modern" ask without the circus of a loud display face).
- Body / UI: **Inter**.
- Chosen over the Premium mood's catalog pairing (Unbounded + Albert Sans) because the retrieved dark-glass reference lane consistently pairs Space Grotesk with Inter, and Unbounded's display weight fights the seriousness of an emergency tool. Recorded as a deliberate deviation.
- Headings use tight tracking (-0.5 to -1.5 depending on size). Body tracking stays at 0.

## Density & spacing
4px base scale. Tokens used in this project:
`space1 4` · `space2 8` · `space3 12` · `space4 16` · `space6 24` · `space8 32` · `space12 48` · `space16 64`
- App-shell nav rows / dense list rows: `space3` floor.
- Standard component padding (buttons, tiles): `space4`.
- Content card internal padding: `space6` minimum.
- Weighty cards (the SOS panel): `space8`.
- Rule held throughout: a card's internal padding <= the gap to its neighbours.

## Shape
Radius scale: `r-sm 12` · `r-md 20` · `r-lg 28` · `r-full` (pills / the SOS disc).
Glass surfaces carry a 1px hairline at ~12% white. No drop shadows for depth on glass — elevation reads through blur, hairline, and glow.

## Glass rules
- Glass is for **elevated** surfaces only: nav bar, cards, sheets, dialogs. Never behind long body text.
- Every glass surface sits over the aurora field so the blur has real content to blur.
- Glass fill: surface at ~55-70% opacity + `BackdropFilter` blur 18-28.

## Motion
Flutter-native (`AnimationController`, implicit animations, `MouseRegion` for web hover). **GSAP and the shadcn/registry component sources do not apply to this stack** and are deliberately not used.
Track: **App shell** — tab/panel transitions, staggered list entrance, animated state change, press/hover springs. No scroll-storytelling hero timeline (there is no marketing page).
- Durations: micro 120ms, standard 220ms, entrance 320ms, ambient aurora 8-14s loops.
- Curves: `Curves.easeOutCubic` for entrances, spring-like `easeOutBack` (clamped) for press release. Never `ease-in` on UI.
- Hover (web/desktop only, pointer-gated): lift 2px + glow bloom. Never hover-only state on touch.
- Reduced motion: respect `MediaQuery.disableAnimations` — aurora freezes, entrances become fades, SOS pulse becomes a static ring.
- SOS pulse is the one continuously-animating element, and only while SOS is active.

## Assets
No photography or illustration: this is an app shell, and the research lane surfaced no legitimate attribution-free safety imagery worth shipping. Visual weight is carried by the aurora field, the existing purple shield mark, a single icon set, and live state. Icons: Material Symbols (Flutter built-in `Icons`), one set throughout — not mixed with emoji.
