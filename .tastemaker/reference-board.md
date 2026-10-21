# Reference board

Created: 2026-10-21
Mode: Operate
Design read: App shell for women at risk and their trusted contacts, mode Operate, with a dark aurora-glass visual lane, dials variance 6 / motion 8 / density 5 / art direction 8.
Dials note: motion is pushed to 8 (above the Operate default of 2-5) because the user explicitly asked for "full juicy" motion. Density held at 5, not the Operate 6-9, because this is a panic-first consumer app, not a cockpit: under stress the primary action must dominate.
Sourcing: viewed via web search on 2026-10-21 (two searches: dark glassmorphism UI 2026; women's safety / SOS panic-button UI patterns). No live site fetches — the safety-app lane returned academic papers and student repos, not shippable design references, so competitor traits below are drawn from those papers' described interaction patterns rather than from viewed visual design.

## Quality bar
- Dark-glass design systems surveyed: near-black ink ground, frosted translucent surfaces over a live gradient, 1px white hairline at ~12% opacity, focus-glow accent system. This is the craft bar for surface treatment.

## Borrow
- Palette/material: 2026 dark-glass systems -> translucent glass layered over a deep aurora gradient; glowing violet/magenta orbs drifting behind the UI so the backdrop blur has something real to blur.
- Type/hierarchy: dark-glass reference system -> geometric display face for headings, neutral grotesque for body (Space Grotesk + Inter), rather than the Premium mood's louder Unbounded display.
- Layout/composition: WoSApp / W-Safe / SheSafe patterns -> the panic control is a single large target on the home surface, not buried in a menu; one-tap activation.
- Motion/interaction: glass systems -> focus/hover glow as the primary feedback channel; aurora drift as ambient life.
- Asset grammar: no stock photography. This is an app shell, so the visual weight is carried by the aurora field, the shield mark, icon set, and live state (pulse, countdown ring), not by imagery.

## Avoid
- Neumorphism / soft-emboss: repeatedly flagged as failing contrast, and this app must stay legible under stress.
- Glass behind body text: glass is for elevated surfaces only (nav, cards, sheets). Text sits on solid or near-solid fills.
- The generic AI indigo-to-purple linear gradient as the hero treatment.
- Emoji as icons.
- Hiding the SOS cancel affordance entirely on screen (the hidden gesture is a *second* path; a visible cancel stays, per the false-alarm risk the research flags).

## Direction contract
- Thesis: a calm dark surface that disappears until it is needed, then becomes unmistakably urgent.
- First viewport: aurora field behind a glass shell; the SOS control is the single dominant element with a living pulse.
- System: locked violet->magenta analogous palette, Space Grotesk + Inter, 4px spacing scale, glass hairline surfaces, Flutter-native motion (no GSAP — wrong stack).
- Risk: overdone glow turns an emergency tool into a toy. Glow is reserved for the SOS state and focus/hover; ordinary cards stay quiet.
