# Game UI Implementation Recipes

Copy-paste-ready CSS/HTML/JS that makes web UI read as *modern game UI* instead of a
bootstrap dashboard. Each recipe is self-contained; all of them assume the shared tokens
below. CSS-first — JS appears only where CSS cannot do the job (particles, count-ups,
gameplay-driven values). Timing and choreography values come from
[motion.md](motion.md); art direction comes from [aesthetics.md](aesthetics.md) — the
tokens below use the Clean Sci-Fi Holo archetype as the running example, so swap them
for your chosen archetype's token block.

**The three tells of "web page pretending to be a game":** rounded-rect cards, instant
state changes, and symmetric/static layouts. These recipes attack exactly those: cut
corners, animate every value change, and put diagonal energy into the composition.

## Shared tokens

```css
:root {
  --ui-bg: #070b12;                    /* near-black blue, never pure black */
  --ui-panel: rgb(13 20 32 / .85);     /* translucent panels over ambience */
  --ui-line: rgb(120 200 255 / .28);   /* hairline borders */
  --ui-text: #d7e4f5;
  --ui-accent: #5ee0ff;                /* energy cyan */
  --ui-danger: #ff3b6b;
  --ui-gold: #ffc94d;
  --ui-font: "Arial Narrow", "Avenir Next Condensed", "Helvetica Neue", Arial, sans-serif;
}
.label { font-family: var(--ui-font); text-transform: uppercase; letter-spacing: .14em; }
```

Typography rule of thumb: condensed/squarish sans, UPPERCASE labels with wide tracking,
tabular numerals for stats (`font-variant-numeric: tabular-nums`). Fonts must stay
self-contained — no Google Fonts/CDN imports; use condensed system stacks + tracking,
or embed a subsetted face as a data URI only when it is truly load-bearing.

---

## 1. Chamfered panel & button (clip-path + hover morph)

**Use for:** any card, panel, or button. The cut corner is the single highest-value
"this is a game" signal.

```css
@property --c { syntax: "<length>"; inherits: true; initial-value: 14px; }

.chamfer {
  --c: 14px;
  clip-path: polygon(
    var(--c) 0, 100% 0, 100% calc(100% - var(--c)),
    calc(100% - var(--c)) 100%, 0 100%, 0 var(--c));
  background: var(--ui-panel);
  transition: --c .25s cubic-bezier(.2, .9, .3, 1.2);
}
.chamfer:hover, .chamfer:focus-visible { --c: 26px; }   /* corner "opens" on hover */

/* Chamfered 1px border: clip-path kills `border`, so frame it with a padded parent */
.chamfer-frame { clip-path: inherit; background: var(--ui-line); padding: 1px; }
```

```html
<div class="chamfer chamfer-frame"><button class="chamfer label">Deploy</button></div>
```

Gotchas: `box-shadow` is clipped away — put glow on a wrapper, or use
`filter: drop-shadow(0 0 12px rgb(94 224 255 / .4))` which follows the clipped shape.
The `--c` morph interpolates because `@property` registers it as a `<length>`.

## 2. Conic-gradient cooldown sweep

**Use for:** ability icons, respawn timers, reload indicators — any radial "time left".

```css
@property --cd { syntax: "<number>"; inherits: false; initial-value: 0; }

.ability { position: relative; width: 64px; height: 64px; }
.ability::after {
  content: ""; position: absolute; inset: 0; border-radius: inherit;
  background: conic-gradient(rgb(4 10 20 / .78) calc(var(--cd) * 1turn), transparent 0);
}
.ability.on-cooldown::after { animation: cd var(--cd-time, 4s) linear forwards; }
@keyframes cd { from { --cd: 1; } to { --cd: 0; } }
```

```html
<div class="ability on-cooldown" style="--cd-time: 6s"><span class="label">Q</span></div>
```

Pure CSS: toggling `.on-cooldown` runs the whole sweep. For gameplay-driven timers, drop
the animation and set `el.style.setProperty('--cd', remaining / total)` per frame.
Add a "ready" pop when it ends: a one-shot `scale(1) → 1.15 → 1` keyframe + glow flash.
(Use an inline SVG icon in the slot for real builds — see aesthetics.md rule 10.)

## 3. Layered glow (multi-shadow + blurred twin)

**Use for:** active states, legendary rarity, anything "energized". One shadow looks
like CSS; three stacked shadows look like light.

```css
.glow {
  color: var(--ui-accent);
  text-shadow:
    0 0 4px  rgb(94 224 255 / .9),   /* hot core */
    0 0 16px rgb(94 224 255 / .5),   /* halo */
    0 0 48px rgb(64 140 255 / .35);  /* atmosphere, shifted hue */
}
.glow-box {
  border: 1px solid rgb(94 224 255 / .6);
  box-shadow:
    inset 0 0 12px rgb(94 224 255 / .18),
    0 0 8px  rgb(94 224 255 / .45),
    0 0 32px rgb(64 140 255 / .25);
}
/* Breathing: animate opacity of a ::after twin, never the shadows themselves (cheap) */
.glow-box::after { content: ""; position: absolute; inset: -2px; border-radius: inherit;
  box-shadow: 0 0 24px rgb(94 224 255 / .5); animation: breathe-ambient 2.4s ease-in-out infinite; }
@keyframes breathe-ambient { 50% { opacity: .35; } }
```

Rule: core tight and bright, halo wide and dim, outermost layer hue-shifted. Identical
radii at different alphas read as a smear, not light.

## 4. Scanline / noise / vignette overlay

**Use for:** one full-screen layer that instantly de-flattens the whole app. Subtlety is
the entire trick — at the right opacity you feel it rather than see it.

```html
<div class="fx" aria-hidden="true"></div>
```

```css
.fx { position: fixed; inset: 0; pointer-events: none; z-index: 999;
  background:
    /* vignette */
    radial-gradient(ellipse at center, transparent 55%, rgb(0 0 0 / .5) 100%),
    /* scanlines */
    repeating-linear-gradient(0deg, rgb(0 0 0 / .14) 0 1px, transparent 1px 3px),
    /* film grain (static SVG turbulence) */
    url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120"><filter id="n"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2"/></filter><rect width="120" height="120" filter="url(%23n)" opacity="0.05"/></svg>');
}
```

Tune: scanlines ≤ .15 alpha, grain ≤ .06, vignette start ≥ 50%. For animated grain, put
the noise on its own element and jitter it: `animation: grain-ambient .4s steps(4) infinite;`
`@keyframes grain-ambient { 50% { transform: translate(-8px, 6px); } }`.

## 5. Segmented health/stamina bar with delayed damage ghost

**Use for:** HP/stamina/XP. The two-layer "ghost trail" (white flash that lags behind
damage) is the most recognizable game idiom on this list.

```html
<div class="bar" style="--fill: .72">
  <i class="ghost"></i><i class="fill"></i>
</div>
```

```css
.bar { position: relative; height: 14px; width: 260px; overflow: hidden;
  background: rgb(0 0 0 / .55); border: 1px solid var(--ui-line);
  clip-path: polygon(6px 0, 100% 0, calc(100% - 6px) 100%, 0 100%); /* slanted ends */ }
.bar > i { position: absolute; inset: 0; transform-origin: left;
  transform: scaleX(var(--fill)); }
.fill  { background: linear-gradient(180deg, #7dffb0, #19c96a 60%, #0d8f4a);
  transition: transform .1s linear; }                        /* snaps down instantly */
.ghost { background: #f4f7ff;
  transition: transform .5s cubic-bezier(.1, .8, .2, 1) .3s; } /* bleeds off late */
/* segment notches, drawn over both layers */
.bar::after { content: ""; position: absolute; inset: 0;
  background: repeating-linear-gradient(90deg, transparent 0 24px, rgb(0 0 0 / .8) 24px 26px); }
```

```js
const setHP = (bar, v) => bar.style.setProperty('--fill', Math.max(0, Math.min(1, v)));
```

On damage the green layer drops in 100ms while the white ghost lingers, then drains —
zero JS beyond setting `--fill`. For heals, flip roles (ghost fast, fill slow) by
toggling a `.healing` class that swaps the two transitions. Stamina variant: same bar in
`--ui-gold`, no segments, plus a low-stamina pulse below 25%.

## 6. Staggered menu entrance (custom-property index)

**Use for:** menu items, inventory grids, results screens. Everything arriving at once
reads as a page load; a 40–80ms cascade reads as a scene transition.

```html
<nav class="menu">
  <button style="--i:0">Continue</button>
  <button style="--i:1">New Game</button>
  <button style="--i:2">Options</button>
  <button style="--i:3">Quit</button>
</nav>
```

```css
.menu > * {
  opacity: 0; animation: menu-in .45s cubic-bezier(.2, .9, .25, 1.1) forwards;
  animation-delay: calc(var(--i) * 65ms);
}
@keyframes menu-in {
  from { opacity: 0; transform: translateX(-28px) skewX(-6deg); }
  to   { opacity: 1; transform: none; }
}
```

The slide direction should match the layout's diagonal energy (recipe 9). Grids: set
`--i` = row + column for a diagonal wave. Re-trigger on re-open by re-adding the class
or toggling `display`.

**Footgun:** `--i` MUST be set on every item (the inline `style="--i:N"` above, or
`el.style.setProperty('--i', i)` in a loop). If it is unset, `calc(var(--i) * 65ms)`
resolves to `0` for all items and the cascade silently collapses to a single
simultaneous fade — no console error, just a lost effect. Verify the index is wired,
not just the keyframe written.

## 7. Corner-bracket focus indicator (keyboard/controller)

**Use for:** every focusable element. Game UIs never use the browser's focus ring; they
use animated target brackets. This is also your controller-navigation affordance.

```css
.focusable { position: relative; outline: none; }
.focusable::before, .focusable::after {
  content: ""; position: absolute; width: 12px; height: 12px;
  border: 2px solid var(--ui-accent); opacity: 0; transition: all .15s ease-out;
}
.focusable::before { top: -7px; left: -7px; border-width: 2px 0 0 2px; }
.focusable::after  { bottom: -7px; right: -7px; border-width: 0 2px 2px 0; }
.focusable:focus-visible::before, .focusable:focus-visible::after {
  opacity: 1; animation: bracket-ambient 1.1s ease-in-out infinite;
}
@keyframes bracket-ambient {
  0%, 100% { transform: translate(0, 0); }
  50% { transform: translate(3px, 3px); }  /* mirrored by symmetry — brackets breathe */
}
```

The `::after` bracket translates toward its own corner too, so both appear to inhale.
Pair with a subtle background shift (`:focus-visible { background: rgb(94 224 255 / .08) }`)
so focus survives even if pseudo-elements are clipped. Four-corner variant: wrap content
in a `<span>` and use its pseudo-elements for the other two corners.

## 8. Holographic & glitch text

**Use for:** titles, rarity labels, error/alert states. Two effects, use one at a time.

```css
/* Holographic sheen — a light band sweeps through the letters */
.holo {
  background: linear-gradient(110deg,
    var(--ui-accent) 20%, #fff 40%, #b48cff 50%, #fff 60%, var(--ui-accent) 80%);
  background-size: 250% 100%;
  -webkit-background-clip: text; background-clip: text; color: transparent;
  animation: holo-ambient 3.5s linear infinite;
}
@keyframes holo-ambient { to { background-position: -250% 0; } }
```

```css
/* Glitch — RGB-split twins slice apart briefly, then rest (the rest is the trick) */
.glitch { position: relative; }
.glitch::before, .glitch::after {
  content: attr(data-text); position: absolute; inset: 0; opacity: 0;
}
.glitch::before { color: #0ff; animation: gl 4s steps(1) infinite; }
.glitch::after  { color: #f0f; animation: gl 4s steps(1) .05s infinite reverse; }
@keyframes gl {  /* active only 0–6% of the loop: fires, then sits idle ~3.8s */
  0%  { opacity: .8; transform: translate(-3px, 0);  clip-path: inset(10% 0 60% 0); }
  2%  { opacity: .8; transform: translate(3px, 0);   clip-path: inset(55% 0 15% 0); }
  4%  { opacity: .8; transform: translate(-2px, 0);  clip-path: inset(30% 0 40% 0); }
  6%, 100% { opacity: 0; }
}
```

```html
<h1 class="glitch label" data-text="CONNECTION LOST">CONNECTION LOST</h1>
```

A glitch that runs constantly is a screensaver; one that fires for 240ms every 4s is an
event. Vary the two pseudo-elements' delays so the slices never align.

## 9. Diagonal energy (skewed containers, angled dividers)

**Use for:** layout composition. Games avoid the 90° grid; a consistent 6–10° slant
across the page creates motion while standing still.

```css
/* Skewed container, un-skewed content — the classic */
.slab { transform: skewX(-8deg); background: var(--ui-panel);
  border-left: 3px solid var(--ui-accent); padding: .6rem 1.4rem; }
.slab > * { transform: skewX(8deg); }   /* counter-skew children */

/* Angled section divider */
.section { clip-path: polygon(0 0, 100% 2.5rem, 100% 100%, 0 calc(100% - 2.5rem)); }

/* Angled stat rows that overlap like fanned cards */
.stat-row { display: flex; }
.stat-row .slab { margin-left: -10px; }  /* slant lets them interlock */
```

Pick **one** angle and reuse it everywhere (slabs, dividers, the health bar's slanted
ends in recipe 5, the entrance skew in recipe 6). Mixed angles read as broken, one angle
reads as art direction.

## 10. Background ambience (gradient pan + starfield)

**Use for:** the page background. A static flat color is a document; slow motion in the
deep background is a world. Keep it *slow* — 20s+ loops, low contrast.

```css
body {
  background: linear-gradient(120deg, #070b12, #0b1526 35%, #101033 70%, #070b12);
  background-size: 300% 300%; animation: pan-ambient 28s ease-in-out infinite alternate;
}
@keyframes pan-ambient { to { background-position: 100% 100%; } }
```

```html
<canvas id="stars" style="position:fixed;inset:0;z-index:-1"></canvas>
<script>
const cv = document.getElementById('stars'), cx = cv.getContext('2d');
let W, H, stars;
const init = () => {
  W = cv.width = innerWidth; H = cv.height = innerHeight;
  stars = Array.from({ length: 140 }, () => ({
    x: Math.random() * W, y: Math.random() * H,
    z: Math.random() * 0.6 + 0.2, r: Math.random() * 1.4 + 0.3 }));
};
addEventListener('resize', init); init();
if (!matchMedia('(prefers-reduced-motion: reduce)').matches) {
  (function tick() {
    cx.clearRect(0, 0, W, H);
    for (const s of stars) {
      s.y -= s.z * 0.35; if (s.y < 0) { s.y = H; s.x = Math.random() * W; }
      cx.globalAlpha = s.z; cx.fillStyle = '#9fd8ff';
      cx.fillRect(s.x, s.y, s.r, s.r);   // square stars: crisper than arcs, and cheaper
    }
    requestAnimationFrame(tick);
  })();
} else {
  for (const s of stars) { cx.globalAlpha = s.z; cx.fillStyle = '#9fd8ff'; cx.fillRect(s.x, s.y, s.r, s.r); }
}
</script>
```

Depth comes from `z` driving both speed and alpha — near stars are faster and brighter.
Swap drift direction to horizontal for a "flying sideways" menu feel. Under reduced
motion the field renders once as a static backdrop instead of animating.

## 11. Button prompt chips (kbd / gamepad glyphs)

**Use for:** "Press F to interact", footer control hints, tooltips. Prompts are what
make a screen feel *playable* rather than clickable.

```css
kbd.key {
  display: inline-grid; place-items: center; min-width: 1.7em; height: 1.7em;
  padding: 0 .35em; font: 700 .8em var(--ui-font); color: var(--ui-text);
  background: linear-gradient(#2a3648, #17202e); border: 1px solid #4a5a72;
  border-radius: .3em; box-shadow: 0 2px 0 #0a0f18;  /* keycap depth */
}
.pad { display: inline-grid; place-items: center; width: 1.7em; height: 1.7em;
  border-radius: 50%; font: 700 .8em var(--ui-font); color: #0a0f18;
  background: var(--pad-c, #8bc34a); box-shadow: 0 0 8px var(--pad-c, #8bc34a); }
.pad-b { --pad-c: #ff5252; } .pad-x { --pad-c: #40a9ff; } .pad-y { --pad-c: #ffd740; }
```

```html
<span class="label"><kbd class="key">F</kbd> Interact</span>
<span class="label"><i class="pad">A</i> Confirm <i class="pad pad-b">B</i> Back</span>
```

Put a prompt strip in a fixed footer bar — it doubles as the app's "controls legend".
On real input-device detection, swap chips per last-used device (`keydown` vs
`gamepadconnected`), don't show both.

## 12. Count-up number micro-helper

**Use for:** scores, damage totals, currency, XP. Numbers that tick up feel *earned*;
numbers that swap feel like a spreadsheet.

```js
function countUp(el, to, dur = 800) {
  const from = parseFloat(el.dataset.v ?? '0');
  el.dataset.v = to;
  const t0 = performance.now();
  requestAnimationFrame(function tick(t) {
    const p = Math.min((t - t0) / dur, 1);
    const e = 1 - Math.pow(2, -10 * p);            // easeOutExpo: fast start, soft landing
    el.textContent = Math.round(from + (to - from) * e).toLocaleString();
    if (p < 1) requestAnimationFrame(tick);
  });
}
countUp(document.querySelector('.score'), 12840);
```

```css
.score { font-variant-numeric: tabular-nums; }  /* stops digits jittering horizontally */
```

Add a scale "pop" on landing: toggle a class that runs `scale(1.12) → 1` over 150ms.
For damage numbers, pair with recipe 3's glow and a rise-and-fade keyframe.

## 13. Options controls without native widgets (stepper + slider)

**Use for:** settings screens. Native `<input type="range">`/checkboxes are the loudest
web tells (aesthetics.md rule 11); games use left/right steppers and drawn sliders.

```html
<div class="opt-row">
  <span class="label">UI Scale</span>
  <div class="stepper" data-min="50" data-max="200" data-step="25" data-value="100">
    <button class="step-btn" data-dir="-1" aria-label="decrease"></button>
    <span class="step-value label">100%</span>
    <button class="step-btn" data-dir="1" aria-label="increase"></button>
  </div>
</div>
```

```css
.opt-row { display: flex; justify-content: space-between; align-items: center; gap: 24px; }
.stepper { display: flex; align-items: center; gap: 14px; }
.step-btn { width: 0; height: 0; border: 9px solid transparent; background: none;
  border-right-color: var(--ui-accent); cursor: pointer; }        /* CSS triangle, no glyphs */
.step-btn[data-dir="1"] { border-right-color: transparent; border-left-color: var(--ui-accent); }
.step-btn:hover, .step-btn:focus-visible { filter: drop-shadow(0 0 6px var(--ui-accent)); }
.step-value { min-width: 5ch; text-align: center; font-variant-numeric: tabular-nums; }
.step-value.tick { animation: tick .12s ease-out; }
@keyframes tick { 50% { transform: scale(1.15); color: var(--ui-accent); } }

/* Slider variant: same track as recipe 5's bar + notches + a diamond thumb */
.slider { position: relative; width: 220px; height: 8px; background: rgb(0 0 0 / .55);
  clip-path: polygon(3px 0, 100% 0, calc(100% - 3px) 100%, 0 100%); }
.slider .fill { position: absolute; inset: 0; transform-origin: left;
  transform: scaleX(var(--v)); background: var(--ui-accent); }
.slider .thumb { position: absolute; top: 50%; left: calc(var(--v) * 100%);
  width: 12px; height: 12px; background: var(--ui-text);
  transform: translate(-50%, -50%) rotate(45deg); }
```

```js
document.querySelectorAll('.stepper').forEach(st => {
  const v = st.querySelector('.step-value'), d = st.dataset;
  st.querySelectorAll('.step-btn').forEach(b => b.addEventListener('click', () => {
    d.value = Math.min(+d.max, Math.max(+d.min, +d.value + +d.step * +b.dataset.dir));
    v.textContent = d.value + '%';
    v.classList.remove('tick'); void v.offsetWidth; v.classList.add('tick');  // restart pulse
  }));
});
```

Both controls must answer ArrowLeft/ArrowRight (and D-pad) — wire `keydown` on the
row, not just clicks. Every change ticks the value (motion.md section 4). Keep a
visually-hidden native input in sync when the form actually submits.

---

## Composition & hygiene

- **Layer order (back → front):** ambience (10) → content panels (1, 9) → HUD bars and
  chips (2, 5, 11, 13) → focus brackets (7) → the fx overlay (4) always on top.
- **One accent, one angle, one font.** The accent color from the tokens drives glow,
  focus, fills; the diagonal angle repeats everywhere; more than one display font kills it.
- **Everything animates on state change, nothing animates at rest** except ambience and
  a single breathing glow. Idle motion budget: two elements max.
- **Reduced motion:** use the `--motion`/`--travel` single-switch pattern from
  motion.md section 7 — do NOT blanket-kill all animation with `!important`; keep
  informational motion (ghost bar, cooldown sweep) and all final styling. Gate JS
  loops (recipe 10's starfield) on `matchMedia('(prefers-reduced-motion: reduce)')`.
- **Performance:** animate only `transform`, `opacity`, and registered custom properties;
  the glow layers (3) are static with an animated-opacity twin for exactly this reason.
- **Accessibility:** the fx overlay is `aria-hidden` and `pointer-events: none`; focus
  brackets require `:focus-visible` to remain functional, not decorative; keep text
  contrast ≥ 4.5:1 *after* the vignette darkens edges.
