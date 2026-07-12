# Game UI Design - Motion

Actionable motion-design guidance for game UI. Default to animated, choreographed,
game-feeling interfaces — a static menu reads as unfinished, and a menu that only
fades reads as a website. This file tells you what "good" motion looks like
concretely: durations, curves, choreography patterns, and code-level techniques.
Implementation snippets for many patterns named here live in
[recipes.md](recipes.md); visual style comes from [aesthetics.md](aesthetics.md).

**How this file coexists with the other references.** The motion rules in
[sharp_edges.md](sharp_edges.md) (motion-sickness-trigger) and
[validations.md](validations.md) (long-animation-duration, no-reduced-motion-check)
are not contradicted here — they are *scoped*:

- **During-gameplay HUD**: the strict rules apply as written. Feedback under
  ~300ms, ease-out, opacity/scale-dominant, minimal travel. The player is busy;
  motion here is signal, never spectacle.
- **Presentation surfaces** (title screen, main menu, pause menu, inventory,
  reward/level-up screens, shops, dialogs): expressive, choreographed motion is
  the expected register. Individual element transitions still stay ≤500ms —
  richness comes from **stagger, overlap, and layered properties**, not from
  long single tweens. A 1.5s title sequence made of 350ms staggered steps passes
  every validation and feels premium; a single 1.5s tween fails both.
- **Ambient loops and progress indicators** (breathing glow, cooldown sweep,
  count-ups) are a third category: continuous or data-driven, low amplitude, not
  gated on player action. Their durations are exempt from the transition caps but
  must obey the amplitude limits in section 6 and be disabled/reduced under
  reduced-motion (section 7).
- **Always** ship the reduced-motion path (section 7). It is what makes the
  expressive default safe.

First decision on any request: *is the player in control of gameplay while this
element animates?* Yes → HUD register (section 5, strict). No → presentation
register (sections 3–4, expressive). Both → treat as HUD.

## 1. Motion Principles

1. **Motion is state communication first.** Every animation must answer one of:
   what changed, where did it come from / go, what can I do now, did my input
   register. If an animation answers none of these, it must be ambient (section 6)
   or it's noise — cut it.
2. **Motion is perceived quality second — and this is not optional.** Players
   read snappy, layered, well-eased motion as "polished game" within seconds of
   the title screen. Two UIs with identical layout are judged tiers apart on
   motion alone. Budget motion like you budget typography.
3. **Enter with energy, exit with economy.** Entrances are choreographed and
   eased-out (fast start, soft settle). Exits are shorter (50–70% of entrance
   duration), simpler, and never block the next screen. The player asked to
   leave — get out of the way. But economy is not absence: a raw
   `classList.add('hidden')` hard cut on a panel that animated in is the #1
   web-toggle tell. Every animated entrance gets a (short) animated exit.
4. **Never gate input on animation.** Menus accept input from the first frame of
   their entrance. Any cinematic sequence (title, reward) is skippable with any
   input, jumping to the final resting state — not to a faster animation.
5. **Animate transform and opacity; treat layout, blur, and clip as budgeted
   spice.** `transform`/`opacity` are compositor-cheap. `clip-path`, small
   `backdrop-filter` blurs, and gradient shifts are affordable in menus (game is
   paused or idle); avoid them on the in-gameplay HUD.
6. **One motion system per game.** Pick one easing vocabulary, one stagger
   interval, one overshoot amount, and reuse them everywhere. Consistent motion
   is invisible; inconsistent motion is what players call "janky."

## 2. Duration & Easing Table

Define these once as tokens and reference them everywhere. Stock keywords
(`ease`, `ease-out`, `ease-in-out`) are a web tell — the custom curves below are
what give motion its character:

```css
:root {
  --ease-out:       cubic-bezier(0.25, 1, 0.5, 1);    /* quart-out: default for everything */
  --ease-out-hard:  cubic-bezier(0.16, 1, 0.3, 1);     /* expo-out: dramatic entrances, big panels */
  --ease-in-out:    cubic-bezier(0.65, 0, 0.35, 1);    /* full-screen crossfades, camera-like moves */
  --ease-snap:      cubic-bezier(0.8, 0, 0.2, 1);      /* selection indicator moves, sweeps */
  --ease-overshoot: cubic-bezier(0.34, 1.56, 0.64, 1); /* back-out ~10%: pop-ins, press release, rewards */
  --ease-in:        cubic-bezier(0.55, 0, 1, 0.45);    /* exits only, and only short ones */
}
```

| Context | Duration | Easing | Notes |
| --- | --- | --- | --- |
| Micro-interaction in (hover, focus, press) | 80–150ms | `--ease-out` | Press-down even faster: 50–80ms |
| Micro-interaction out (unhover, release) | 150–250ms | `--ease-out` | Out slower than in — feels smooth, not blinky |
| HUD feedback hit (flash, tick, shake) | 60–120ms | linear or `--ease-out` | Recovery 150–300ms ease-out |
| Element entrance (panel, card, list item) | 250–400ms | `--ease-out-hard` | Travel ≤32px; pair with fade |
| Element exit | 120–250ms | `--ease-in` or `--ease-out` | Always shorter than the entrance |
| Selection indicator move | 150–250ms | `--ease-snap` | Distance-independent duration |
| Full-screen transition | 400–600ms total | `--ease-in-out` | Built from ≤400ms per-element steps |
| Title/reward choreography | 900–2500ms total | mixed | Sequence of 250–500ms staggered steps; skippable |
| Pause overlay in / out | ≤250ms / ≤150ms | `--ease-out` / `--ease-in` | Player is mid-game — fastest presentation surface |
| Ambient loop | 2s–20s per cycle | linear or sine in-out | Low amplitude, see section 6 |
| Cooldown sweep / progress | data-driven | linear | Duration = the actual cooldown; not a "transition" |
| Number count-up | 400–800ms | ease-out on value | Clamp regardless of delta size |

**Spring feel guidance.** If your stack has real springs (Unity tweens, Framer
Motion, react-spring), translate as: HUD = critically damped (damping ratio 1.0,
no overshoot, settle ≤200ms). Menu pop-ins and reward elements = underdamped,
damping ratio 0.6–0.75, stiffness tuned so exactly **one** visible overshoot of
5–12% occurs. Two or more bounces reads as toy UI, and elastic/bounce curves are
on the sharp-edges problem list — one restrained overshoot is the game-feel
sweet spot. In CSS, `--ease-overshoot` approximates this.

**Scale discipline.** Scale entrances start at 0.95–0.97, never from 0. Scale
from zero is a web-app tell and reads as popping out of nowhere; 0.96→1 reads as
the element taking focus.

## 3. Choreography Patterns

Choreography = multiple elements animating in a deliberate order with overlap.
The stagger interval is the single biggest lever for "game feel": **30–80ms
between siblings**, and the next element starts while the previous is ~40–60%
done. Sequential (wait-for-finish) choreography feels sluggish; simultaneous
feels cheap.

### 3.1 Staggered menu entrance

Items slide up 12–24px + fade in, top to bottom, 40–60ms apart.

```css
.menu-item {
  animation: menu-in 350ms var(--ease-out-hard) both;
  animation-delay: calc(var(--i) * 50ms);  /* --i set per item: 0,1,2... */
}
@keyframes menu-in {
  from { opacity: 0; transform: translateY(16px); }
  to   { opacity: 1; transform: translateY(0); }
}
```

Rules: cap the total (last delay + duration) at ~600ms for menus visited often —
with 6 items at 50ms stagger + 350ms duration you land at 600ms. For 10+ item
lists, decay the stagger (50ms for the first 5, 20ms after) or cap `--i`. Focus
the first item immediately; input works during the cascade.

**Wire the index or the cascade silently dies.** `animation-delay: calc(var(--i)
* 50ms)` does nothing unless `--i` is actually set per element — `style="--i:0"`,
`style="--i:1"`, … in the markup, or a JS loop
(`items.forEach((el, i) => el.style.setProperty('--i', i))`). A delay that reads
an unset custom property falls back to `0` for every item, so they all enter
together and the whole point is lost with no error. This is the single most
common way staggered entrances regress to "everything appears at once" — always
verify the index is assigned, not just the keyframe written.

### 3.2 Panel slide + fade + clip reveal

For side panels, inventory pages, detail panes. Layer three cheap properties
instead of one big movement — short travel (16–32px, **never from off-screen**,
which is on the sharp-edges list), fade, and a clip-path wipe that makes the
edge feel machined:

```css
.panel {
  animation: panel-in 400ms var(--ease-out-hard) both;
}
@keyframes panel-in {
  from { opacity: 0; transform: translateX(24px);
         clip-path: inset(0 0 0 12%); }
  to   { opacity: 1; transform: translateX(0);
         clip-path: inset(0 0 0 0); }
}
.panel > * { /* contents stagger AFTER the panel starts, overlapping it */
  animation: menu-in 300ms var(--ease-out) both;
  animation-delay: calc(120ms + var(--i) * 40ms);
}
```

Directional grammar: the panel enters from the side it logically lives on, and
exits the same side (reverse, 60% duration). Tab switches within the panel reuse
the same pattern at half scale: 8px travel, 200ms, contents-only.

### 3.3 Title screen sequence (logo → menu cascade)

The title screen is the one place a 1.5–2.5s total sequence is expected. Build
it as a timeline of short steps:

1. **0ms** — background fades in / ambient loop starts (600ms fade).
2. **300ms** — logo enters: scale 1.06→1 + fade, 700–900ms `--ease-out-hard`.
   Optionally a single light-sweep across the logo (one pass, 600ms, then stop).
3. **Beat** — 150–250ms hold. Beats are what separate choreography from a pile
   of tweens.
4. **~1200ms** — menu cascade: staggered entrance per 3.1.
5. **After settle** — "Press any button" begins a slow pulse (opacity 0.6↔1.0,
   1.6s sine loop) and ambient/idle motion takes over (section 6).

Any input at any point completes the timeline instantly to the resting state and
executes that input against the settled UI. Returning to the title from a menu
replays only step 4 — never make the player rewatch the logo. If the logo (or
any element) persists across two screens at different positions, move it as a
shared element (150–250ms `--ease-snap`) instead of hard-swapping two copies.

### 3.4 Pause menu overlay in/out

Pause interrupts gameplay, so it gets the fastest presentation treatment:

- **In (≤250ms total):** backdrop fades to scrim + optional blur ramp 0→8px over
  180ms; panel scales 0.96→1 + fades 200ms `--ease-out`; items stagger 30ms.
  Game world visibly freezing/desaturating behind the scrim sells "paused"
  better than any panel styling.
- **Out (≤150ms):** single group fade + scale to 0.98, `--ease-in`. No stagger
  on exit; unpausing must feel instant because the player is re-entering danger.
- Resume gameplay input works the frame the unpause animation starts, not when
  it ends.

## 4. Micro-Interactions

Every interactive element responds to hover/focus, press, and selection. A menu
where only the background color changes is the #1 static-UI tell.

- **Hover/focus:** combine ≥2 channels — e.g. scale 1.02–1.03 + border/glow
  brighten + text color lift, 120ms in / 200ms out. For controller focus (no
  hover-off state to rest at), add an **idle focus pulse**: a breathing glow or
  outline at 1.4–2s sine loop so the focused item stays findable after the
  player looks away. This is the controller equivalent of a cursor.
- **Press:** scale to 0.97 in 50–80ms on press-down; on release spring back with
  `--ease-overshoot` over 250ms. Down-fast/up-springy is the core of tactile
  feel. Fire the action on press-down (or release, per platform convention) —
  never after the animation.
- **Selection sweep (the "magic line"):** for tabs and vertical menus, use one
  shared indicator (underline, side-bar, or highlight plate) that *slides*
  between items — 150–250ms `--ease-snap` — instead of fading out on one item and
  in on another. Implement it as ONE positioned element whose `transform`/`left`
  animates to the active item's position, not a per-item `::after` that cuts in
  and out (a cut-in underline is the web-tab tell this pattern exists to replace).
  The sliding indicator is a shared-element transition; it makes navigation feel
  physical and shows direction. The selected item itself should also shift
  slightly (2–4px nudge or scale), not only change color — a pure color swap on
  the row reads as a hyperlink, not a game cursor. Add a subtle background sweep
  (gradient moving across the newly selected item, one 200ms pass) for extra
  energy on presentation surfaces; skip the sweep on in-gameplay radial/quick menus.
- **Value changes:** steppers, sliders, and counters acknowledge every discrete
  change — a 100ms tick-flash on the value text or a 1→1.06→1 pulse. Silent
  mutation of a number the player just changed feels broken.

Sync audio to the motion: press sound on press-down frame, confirm sound at the
start of the transition it triggers. Motion without matching audio feels mute;
audio without motion feels broken. Even in demos/prototypes, ship a stubbed
audio layer — a no-op `playSfx('hover'|'confirm'|'back'|'ready')` called at the
right frames — so the intent is visible and real sounds drop in later.

## 5. HUD Feedback (during gameplay — strict register)

HUD motion obeys sharp_edges rules fully: short, ease-out, opacity/scale, tiny
travel. Within those limits, these patterns carry enormous game feel:

- **HUD boot-in (the one exception to "static during play").** The *first
  appearance* of the HUD — level start, respawn, exiting a cutscene — is a
  presentation moment, not a during-play moment, so it gets a one-time
  choreographed assembly: vitals, ability row, minimap, and objective tracker
  stagger in from their anchored edges (per-element `--i`, 40–60ms apart, ≤400ms
  each) rather than snapping on all at once. This is the difference between a HUD
  that "boots up" and one that "was just already there" (a static-on-load HUD is
  a repeatable web-page tell). After this one-time assembly the HUD reverts to the
  strict register for the rest of play — no re-animating on every value change.

- **Damage flash:** on taking damage, flash a screen-edge vignette (not a
  full-screen solid) to 40–60% opacity in 60–80ms, decay over 200–300ms. Flash
  the health bar itself white for one 80ms pulse simultaneously. Hard limit:
  never more than 3 flashes per second sustained (photosensitivity); repeated
  hits extend the decay instead of re-flashing.
- **Two-layer damage bar (fighting-game style):** the front (true) bar snaps to
  the new value instantly (≤80ms). Behind it, a ghost bar in a contrasting color
  (white/orange) holds the old value for 300–500ms, then drains to match over
  300–400ms `--ease-out`. The ghost communicates *how much* was just lost while
  the true bar stays honest. Healing reverses the roles: ghost fills instantly
  as a preview, true bar fills over 300ms to meet it. Big single hits read
  perfectly; chip damage accumulates in the ghost. This is the single
  highest-value HUD motion pattern — default to it for any health/resource bar.
- **Cooldown sweep + ready flash:** cooldowns use a radial conic-gradient wipe,
  linear, lasting exactly the cooldown (data-driven duration — exempt from
  transition caps; it is a progress indicator). At ready: one pop — icon scale
  1→1.12→1 with `--ease-overshoot` + a 250ms white flash/ring burst — then
  settle to a subtle ready-state glow. The pop is the signal players actually
  watch for; the sweep is just reassurance.
- **Number count-up:** score/currency/XP totals roll from old to new value over
  400–800ms with ease-out applied to the *value* (big digits move first, last
  few tick in). Clamp duration regardless of delta; a 10× pickup should not
  animate 10× longer. New input during a roll snaps to current and starts the
  new roll. Pair with a brief 1→1.08→1 scale pulse on the number container at
  roll start. For damage numbers themselves, follow patterns.md (float-and-fade,
  clustering).
- **Distinct urgencies get distinct signatures.** Never reuse one pulse keyframe
  for low-health + objective marker + cooldown-ready: danger pulses fast and
  strong (0.5–0.8s, high contrast), attention pulses slow and subtle (1.5–2s,
  low amplitude), ready-states pop once then hold a quiet glow. If two signals
  share frequency and amplitude, the player reads them as the same priority.

## 6. Ambient / Idle Motion

Ambient motion is what makes a title screen or menu feel alive while nothing is
happening. It is continuous, slow, and low-amplitude — decoration with a pulse,
never demanding attention.

- **Slow gradient drift:** background gradient position/hue shifting over
  10–20s loops (`background-position` or an overlaid gradient layer's opacity).
  Movement should be imperceptible in any single second.
- **Particles:** sparse floating motes/embers, 6–20 particles, rising or
  drifting at 10–30px/s, opacity ≤0.4, individually randomized duration/delay so
  the loop never visibly repeats. CSS transforms or a single canvas — never per-
  frame layout.
- **Scanline / grain drift:** for retro or sci-fi styles, a repeating scanline
  texture translating vertically over 8–15s at ≤6% opacity, or a stepped grain
  jitter at low frequency (~8 steps/s, `steps()` timing).
- **Breathing glow:** key elements (logo, focused item, "press start") pulse
  glow/opacity on a 2–4s sine loop. Amplitude limit: opacity delta ≤15%, scale
  delta ≤2%. This doubles as the controller focus pulse from section 4.

Rules: ambient layers live on presentation surfaces only — during gameplay the
HUD carries zero ambient motion (a breathing low-health warning is *feedback*,
not ambient, and is allowed). Suffix ambient keyframes/classes with `-ambient`
so their long durations are self-documenting when the long-animation-duration
validation flags them — the validator targets transitions; a 12s linear ambient
loop at 6% opacity is not a transition, but it must still respect section 7.

## 7. Reduced-Motion Strategy

Reduced motion is a fallback *rendering* of the same design, not a deletion of
it. The goal: a player with `prefers-reduced-motion` (or the in-game Reduce
Motion setting — support both, the in-game setting wins in both directions)
still sees the same styled, confident UI. **Keep fades, colors, glows, and final
styling. Cut travel, duration, overshoot, and loops.** A blanket
`* { animation: none; transition: none }` nuke is the lazy version — it also
kills non-vestibular color/opacity feedback and leaves the UI feeling broken.

| Full motion | Reduced fallback |
| --- | --- |
| Staggered slide+fade entrance | Fade-only, stagger halved or removed, ≤120ms |
| Panel slide + clip reveal | Fade in place, 100–120ms |
| Title logo sequence | Elements fade in in order, no scale/travel; total ≤400ms |
| Hover/press scale + spring | Color/glow change only, 80ms; no overshoot anywhere |
| Selection indicator slide | Indicator jumps, 0ms or 80ms fade |
| Damage vignette flash | Single reduced-opacity (≤30%) flash, no pulse trains |
| Two-layer bar ghost drain | Keep it — it's information; optionally shorten hold to 200ms |
| Cooldown sweep | Keep — progress info; ready state = color change, no pop |
| Number count-up | Instant snap + brief highlight of the changed value |
| Ambient loops (gradient, particles, scanline) | Freeze at a good-looking static frame; keep static glow styling |
| Screen shake on UI | Off, always (also off at full motion — shake belongs to the world) |

Implementation: drive everything from two custom properties so the fallback is
one switch, not a parallel stylesheet:

```css
:root { --motion: 1; --travel: 1; }
@media (prefers-reduced-motion: reduce) {
  :root { --motion: 0.4; --travel: 0; }   /* durations shrink, travel dies */
}
:root[data-reduce-motion="on"]  { --motion: 0.4; --travel: 0; }
:root[data-reduce-motion="off"] { --motion: 1;   --travel: 1; }  /* in-game setting overrides OS */

.menu-item {
  animation-duration: calc(350ms * var(--motion));
  animation-delay: calc(var(--i) * 50ms * var(--motion));
}
@keyframes menu-in {
  from { opacity: 0; transform: translateY(calc(16px * var(--travel))); }
  to   { opacity: 1; transform: translateY(0); }
}
:root[data-reduce-motion="on"] .bg-ambient { animation-play-state: paused; }
@media (prefers-reduced-motion: reduce) {
  :root:not([data-reduce-motion="off"]) .bg-ambient { animation-play-state: paused; }
}
```

(Adapt the pattern to your engine: in Unity/Godot, a global `MotionScale` float
multiplying tween durations and a `TravelScale` multiplying offsets achieves the
same single-switch behavior.)

Ship order: build the full-motion version first with the tokens above, then
verify the reduced path by toggling the setting — every screen must remain
styled, legible, and complete with `--motion: 0.4, --travel: 0`. If a screen
looks broken with travel at zero, its design was leaning on motion to hide a
layout problem; fix the layout.

## Quick Self-Audit (run before delivering)

- [ ] Do sibling elements enter as a stagger, AND is the per-element index
      (`--i`/`--r`) actually assigned in markup or JS — not a keyframe that reads
      an unset property and collapses to a simultaneous fade?
- [ ] Does every animated entrance have an animated exit — zero raw
      hidden-toggles on panels/overlays/toasts?
- [ ] Are top-level screen changes (start game, back to title, scene swap)
      animated (fade-to-black, dissolve), not instant `textContent`/`display` swaps?
- [ ] Does confirm/press have visible feedback (press scale, flash, or sweep),
      including on the successful path (not only the denied/error path)?
- [ ] Is tab/menu selection a single sliding indicator (magic line) that moves,
      not a per-item underline that cuts in/out — and does the row itself shift,
      not only change color?
- [ ] Are all curves custom tokens (`cubic-bezier`), not bare `ease`/`ease-out`,
      and is every token you defined actually referenced (no dead `--ease-*`)?
- [ ] Do numeric totals (score, gold, XP, HP text) count-up/roll rather than
      snap via `textContent`? Do steppers/sliders tick or pulse on change?
- [ ] Is there one ambient layer on presentation surfaces (and none on the
      in-gameplay HUD)?
- [ ] Do different urgencies use different pulse frequencies/amplitudes?
- [ ] Are `playSfx()` stubs called on hover/confirm/back/ready frames?
- [ ] Is reduced-motion a styled fallback (custom-property switch), not a
      blanket animation kill?
- [ ] Is input accepted from the first frame, with cinematics skippable?
