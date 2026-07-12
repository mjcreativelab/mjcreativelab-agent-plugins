# Game UI Aesthetics — Art Direction Reference

This file covers **visual style**: what makes web-based game UI look like a shipped
modern video game instead of a dark-themed web page. It is orthogonal to
[patterns.md](patterns.md) (functional patterns), [sharp_edges.md](sharp_edges.md)
(failure modes), and [validations.md](validations.md) (checkable rules) — apply those
first, then use this file to art-direct the result. When aesthetics conflict with
readability or accessibility rules, readability wins; the archetypes below are all
achievable within those constraints.

**How to use:** 1) Pick ONE archetype via the selection heuristic. 2) Apply its token
block and shape language everywhere. 3) Run the cross-archetype craft rules as a
final pass. Never blend archetype token sets — commit fully to one, borrowing at most
a single accent technique from another.

---

## Archetype Selection Heuristic

Map the user's request to an archetype. Signals, strongest first:

| Signal in request | Archetype |
|---|---|
| sci-fi, space, shooter HUD, mech, tactical, military, "like Destiny/Halo/Titanfall" | 1. Clean Sci-Fi Holo |
| stylish, anime, rhythm, arcade, bold, "like Persona/Splatoon", youth-culture, energetic | 2. Kinetic Graphic Pop |
| cyberpunk, hacker, neon, terminal, dystopia, glitch, "like Cyberpunk 2077" | 3. Cyberpunk Glitch |
| atmospheric, artistic, puzzle, contemplative, minimal, "like Journey/NieR/Inside" | 4. Minimal Ethereal |
| fantasy, RPG, medieval, souls-like, loot, inventory-heavy, "like Diablo/Elden Ring" | 5. Ornate Fantasy |
| competitive, esports, PvP, leaderboard, stats, lobby, "like Valorant/Rocket League" | 6. Esports Broadcast |

Tie-breakers when signals are weak or mixed:

- **Genre unknown, dense data UI** (inventory, stats, skill trees) → 1 (Sci-Fi Holo)
  reads as "game" while handling tables/numbers gracefully.
- **Genre unknown, marketing/landing/menu-only** → 2 (Kinetic Pop) delivers maximum
  "this is a game" per line of CSS.
- **Casual / cozy / family** → 4 (Minimal Ethereal) but warm the palette and round
  the corners (the only archetype where border-radius > 8px is allowed).
- **Horror** → 3 with the neon stripped to a single sickly accent, or 5 with the
  gold stripped to bone-white.
- **User provided brand colors** → keep their hue, adopt the archetype's *value
  structure* (background darkness, accent saturation, neutral temperature).

State the chosen archetype and one-line rationale before writing code, so the user
can redirect cheaply.

---

## Archetype 1 — Clean Sci-Fi Holo

**Touchstones:** Destiny 2, Titanfall 2, Halo Infinite, Deus Ex: Mankind Divided.
**Mood:** competent, calm, military-industrial precision. The UI is a projected
instrument, not a decoration.

- **Palette strategy:** near-black blue-gray base (never pure #000), desaturated
  ice-white text, ONE saturated accent (cyan or Destiny-gold) reserved for
  interactive/selected states. Danger red and shield blue stay semantic-only.
- **Typography:** condensed grotesque, ALL-CAPS labels with wide tracking, big
  thin numerals. Hierarchy comes from size + tracking, not weight.
- **Shape language:** hairline (1px) strokes, chamfered corners (45° clips), corner
  brackets, long horizontal rules. No border-radius anywhere.
- **Texture/layering:** faint grid or scanlines at 2–4% alpha, soft outer glow on
  the accent, panels are translucent glass over the scene (`backdrop-filter`).
- **Motion accent:** elements "boot up" — wipe in from a 1px line, 150ms, ease-out.

```css
:root {
  --bg: #0b0f14;            /* blue-black, never #000 */
  --panel: rgba(16, 24, 32, 0.72);
  --line: rgba(140, 170, 190, 0.28);
  --text: #cfd8dc;          /* ice white, slightly blue */
  --text-dim: #6b7a85;
  --accent: #ffce54;        /* Destiny gold; alt: #4fd8eb cyan */
  --danger: #ff5252;
  --font-display: "Arial Narrow", "Avenir Next Condensed", "Helvetica Neue", Arial, sans-serif;
  --font-data: "SF Mono", "Cascadia Mono", Consolas, monospace;
}
.panel {
  background: var(--panel);
  border: 1px solid var(--line);
  clip-path: polygon(12px 0, 100% 0, 100% calc(100% - 12px), calc(100% - 12px) 100%, 0 100%, 0 12px);
  backdrop-filter: blur(6px);
}
.label { font: 600 11px/1 var(--font-display); letter-spacing: 0.18em; text-transform: uppercase; color: var(--text-dim); }
.value { font: 200 34px/1 var(--font-display); font-variant-numeric: tabular-nums; color: var(--text); }
.selected { border-color: var(--accent); box-shadow: 0 0 14px rgba(255, 206, 84, 0.25), inset 0 0 0 1px rgba(255,206,84,.35); }
```

---

## Archetype 2 — Kinetic Graphic Pop

**Touchstones:** Persona 5, Splatoon 3, Hi-Fi Rush, Jet Set Radio.
**Mood:** loud, confident, graphic-design-as-gameplay. The UI *is* the star; it
shouts and stays readable because contrast is absolute.

- **Palette strategy:** pure black + pure white + ONE screaming hue (Persona red
  #e60012, or acid green/orange). Zero mid-tones, zero gray gradients. A second hue
  only for semantic danger/success.
- **Typography:** the heaviest weight available, italic/oblique, mixed sizes inside
  one word is fine. Text sits on shape plates, never directly on the scene.
- **Shape language:** jagged irregular polygons, star bursts, torn-paper edges,
  everything rotated -2° to -6° off axis. No two panels share the same angle.
- **Texture/layering:** halftone dot fields, hard offset shadows (solid color, zero
  blur), white outlines around black plates and vice versa.
- **Motion accent:** elements slam in with overshoot; selection swaps the whole
  plate's color (black↔accent), not a subtle highlight.

```css
:root {
  --ink: #0a0a0a; --paper: #ffffff; --accent: #e60012;
  --font-display: "Arial Black", "Avenir Next", "Helvetica Neue", Arial, sans-serif;
}
.plate {
  background: var(--ink); color: var(--paper);
  transform: rotate(-3deg);
  clip-path: polygon(2% 8%, 98% 0, 100% 86%, 4% 100%);      /* irregular quad */
  box-shadow: 6px 6px 0 var(--accent);                       /* hard, unblurred */
  padding: 10px 22px;
}
.plate h2 { font: italic 900 clamp(22px, 4vw, 44px)/0.95 var(--font-display); text-transform: uppercase; transform: skewX(-6deg); }
.halftone {                                                   /* overlay layer */
  background-image: radial-gradient(circle, rgba(255,255,255,0.14) 1px, transparent 1.5px);
  background-size: 7px 7px;
}
.selected { background: var(--accent); color: var(--paper); box-shadow: 6px 6px 0 var(--ink); }
```

---

## Archetype 3 — Cyberpunk Glitch

**Touchstones:** Cyberpunk 2077, Ruiner, Katana ZERO, Observer.
**Mood:** corrupted machine luxury. The UI is a hostile terminal that barely
tolerates the user.

- **Palette strategy:** off-black warm base, acid yellow OR cyan as primary (2077
  uses #fcee0a on #0d0d0f), magenta/red strictly for glitch artifacts and alerts.
  Accent covers large fills, not just lines — big yellow blocks with black text.
- **Typography:** monospace for all data/values; condensed caps for headers.
  Decorate labels with terminal syntax: `//`, `>`, `_`, trailing block cursor.
- **Shape language:** brutal rectangles with one notched corner, heavy single-side
  borders (4–6px left edge), asymmetric everything. No curves, no chamfer softness.
- **Texture/layering:** chromatic aberration (red/cyan text-shadow split),
  scanlines, occasional 1-frame clip-path glitch on hover/appear only — constant
  glitching is amateur; shipped games glitch on *events*.
- **Motion accent:** instant (0ms) state changes with a 2-frame RGB-split flicker.

```css
:root {
  --bg: #0d0d0f; --panel: #16161a; --accent: #fcee0a;
  --cyan: #00f0ff; --alert: #ff003c; --text: #e8e6e3; --dim: #6f6f78;
  --font-head: "Arial Narrow", "Helvetica Neue", Arial, sans-serif;
  --font-mono: "SF Mono", "Cascadia Mono", Consolas, "Courier New", monospace;
}
.panel { background: var(--panel); border-left: 5px solid var(--accent);
  clip-path: polygon(0 0, 100% 0, 100% calc(100% - 14px), calc(100% - 14px) 100%, 0 100%); }
.tag { display: inline-block; background: var(--accent); color: #000;
  font: 700 11px/1 var(--font-mono); padding: 3px 8px; text-transform: uppercase; }
.tag::before { content: "// "; }
.glitch-text { color: var(--text); text-shadow: -1.5px 0 var(--alert), 1.5px 0 var(--cyan); }
.scanlines::after { content: ""; position: absolute; inset: 0; pointer-events: none;
  background: repeating-linear-gradient(0deg, rgba(0,0,0,0.22) 0 1px, transparent 1px 3px); }
```

---

## Archetype 4 — Minimal Ethereal

**Touchstones:** NieR: Automata, Journey, Inside, Gris, Sable.
**Mood:** quiet, literary, melancholic. The UI whispers; restraint IS the style.
Hardest archetype to get right because there is nothing to hide behind.

- **Palette strategy:** narrow-value, desaturated, warm neutrals — NieR's bone/olive
  (#dcd8c2 on #4a4944) or a misty cool equivalent. Contrast between text and ground
  stays moderate everywhere except the one focused element. No saturated accent at
  all; "accent" is a value shift plus an underline.
- **Typography:** light-weight wide-tracked serif or humanist sans, sentence case or
  lightly-tracked small caps. Generous line-height. Type is 90% of the design.
- **Shape language:** thin rules, small squares/diamonds as bullets and cursors,
  perfect alignment to a strict grid. Ornament budget: one hairline + one glyph.
- **Texture/layering:** paper grain at 2–3% alpha over everything, soft vignette,
  panels differ from background by ≤6% lightness — separation comes from spacing.
- **Motion accent:** slow fades only (300–500ms), nothing moves position.

```css
:root {
  --ground: #b3ae9d;        /* NieR parchment; dark mode: #45443c */
  --panel: #a8a392;
  --ink: #4a4944;           /* dark mode text: #dcd8c2 */
  --ink-dim: #75726a;
  --font-body: "Iowan Old Style", "Palatino Linotype", Palatino, Georgia, serif;
}
body { background: var(--ground); color: var(--ink); font-family: var(--font-body); }
.menu-item { font-size: 17px; letter-spacing: 0.08em; padding: 10px 16px; color: var(--ink-dim); }
.menu-item.selected { color: var(--ink); background: var(--panel); position: relative; padding-left: 34px; }
.menu-item.selected::before { content: ""; position: absolute; left: 16px; top: 50%;
  width: 8px; height: 8px; margin-top: -4px; background: var(--ink); }  /* NieR square cursor */
.rule { height: 1px; background: currentColor; opacity: 0.35; }
.grain { position: fixed; inset: 0; pointer-events: none; opacity: 0.05; mix-blend-mode: multiply;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9'/%3E%3C/filter%3E%3Crect width='120' height='120' filter='url(%23n)'/%3E%3C/svg%3E"); }
```

---

## Archetype 5 — Ornate Fantasy

**Touchstones:** Diablo IV, Elden Ring, Baldur's Gate 3, World of Warcraft.
**Mood:** aged material weight — stone, parchment, forged gold. The UI is an
artifact that has survived centuries.

- **Palette strategy:** deep umber/charcoal grounds, parchment text, metallic gold
  accents built from *gradients* (flat gold hex reads as mustard). Blood red and
  arcane blue reserved for resource bars.
- **Typography:** full-presence serif; small-caps tracked labels
  (`font-variant-caps: small-caps`). Numerals in the same serif — a geometric sans
  number in a fantasy panel instantly breaks the fiction.
- **Shape language:** framed panels with double borders (outer metal, inner shadow
  gap), corner ornaments (rotated squares/diamonds via pseudo-elements), pointed or
  beveled bar ends. Symmetry is correct here — this is the one archetype that wants it.
- **Texture/layering:** vignette inside every panel (engraved depth), subtle noise,
  gradient "light from above" on metal edges, inner shadows instead of drop shadows.
- **Motion accent:** slow glows and ember-like pulses; nothing snaps or slides fast.

```css
:root {
  --ground: #17120e; --panel: #221a13; --parchment: #d9c9a3; --dim: #8a7a5c;
  --gold-hi: #e8c876; --gold-lo: #7a5b23; --blood: #8c1f1f; --arcane: #274a7a;
  --font-serif: "Iowan Old Style", "Palatino Linotype", Palatino, Georgia, "Times New Roman", serif;
}
.panel {
  background: radial-gradient(ellipse at 50% 0%, #2b2117 0%, var(--panel) 70%);
  border: 1px solid var(--gold-lo);
  box-shadow: inset 0 0 0 3px var(--ground), inset 0 0 0 4px rgba(232,200,118,0.35),
              inset 0 0 40px rgba(0,0,0,0.6);                /* double frame + engraved depth */
}
.panel::before, .panel::after { content: ""; position: absolute; top: -5px;
  width: 8px; height: 8px; background: var(--gold-hi); transform: rotate(45deg); }  /* corner diamonds */
.panel::before { left: -5px; } .panel::after { right: -5px; }
.heading { font-family: var(--font-serif); font-variant-caps: small-caps; letter-spacing: 0.12em;
  color: var(--gold-hi); text-shadow: 0 1px 0 #000; }
.bar-health { background: linear-gradient(180deg, #b03030 0%, var(--blood) 55%, #5a1212 100%);
  border: 1px solid #000; box-shadow: inset 0 1px 0 rgba(255,255,255,0.25); }  /* specular top */
```

---

## Archetype 6 — Esports Broadcast

**Touchstones:** Valorant, Rocket League, Overwatch 2, Apex Legends menus.
**Mood:** televised sport — fast, legible from across the room, sponsor-ready.
Function-forward but with aggressive graphic momentum.

- **Palette strategy:** dark cool neutral base, white heavy numerals, one saturated
  team/brand accent at full chroma, its complementary reserved for "enemy" data.
  Backgrounds may carry a subtle diagonal texture; data plates stay flat.
- **Typography:** geometric or condensed caps, tight leading, huge tabular numerals.
  Numbers are the heroes — score, timer, K/D get 2–4× the size of their labels.
- **Shape language:** parallelogram everything — skewed containers with
  counter-skewed content, angled bar ends, sharp chips and tabs. 90° corners read
  as "admin dashboard"; the slant is the genre marker.
- **Texture/layering:** flat fills + one subtle diagonal stripe field at low alpha,
  thin accent underlines, gradient only inside progress fills.
- **Motion accent:** slide + snap on axis (wipes, not fades); count-up numerals.

```css
:root {
  --bg: #101418; --panel: #1a2026; --text: #f2f5f7; --dim: #8b98a5;
  --accent: #ff4655;        /* Valorant red; alt teal #18e5c8 */
  --enemy: #3ac6ff;
  --font-display: "Arial Narrow", "Avenir Next Condensed", "Helvetica Neue", Arial, sans-serif;
}
.chip { background: var(--panel); transform: skewX(-12deg); border-bottom: 2px solid var(--accent); padding: 8px 20px; }
.chip > * { transform: skewX(12deg); }                        /* counter-skew content */
.score { font: 800 clamp(28px, 5vw, 56px)/1 var(--font-display); font-variant-numeric: tabular-nums; color: var(--text); }
.label { font: 700 11px/1 var(--font-display); letter-spacing: 0.14em; text-transform: uppercase; color: var(--dim); }
.stripes { background: repeating-linear-gradient(-45deg, rgba(255,255,255,0.03) 0 2px, transparent 2px 10px); }
.bar { height: 8px; background: #0a0d10; clip-path: polygon(0 0, 100% 0, calc(100% - 8px) 100%, 0 100%); }
.bar-fill { background: linear-gradient(90deg, var(--accent), #ff7a85); }
```

---

## Cross-Archetype Craft Rules

These separate "shipped game" from "dark web page" regardless of archetype. Apply as
a final pass over any game UI you produce.

### 1. Layer in threes, minimum
A shipped panel is never one flat fill. Stack at least: (a) ground treatment behind
it (scrim, vignette, blur, or texture), (b) the panel body with a border OR inner
highlight, (c) an accent layer (edge light, corner mark, glow, or stripe). A single
`background: #1f2937; border-radius: 8px` card is a web page by definition.

### 2. One consistent light source
Give every surface a top-lit bias: `inset 0 1px 0 rgba(255,255,255,0.06–0.25)` on
raised elements, darker bottoms on bars, radial glow *behind* the focal element
rather than drop shadow below it. Specular accents (that 1px inner top highlight)
are the single cheapest "rendered, not painted" signal.

### 3. Diagonal energy
Web pages are 90° grids; game UI almost never is. Every archetype has an angle
budget — chamfers (1), rotation (2), notches (3), nothing (4 — its restraint is the
angle), bevels/points (5), skew (6). Introduce the angle through `clip-path` and
`transform`, keep body text unskewed, and reuse the SAME angle value everywhere
(one of 45°, 30°, or 12° — mixing angles looks broken, not kinetic).

### 4. Frame the screen, not just the components
HUD elements anchor to screen edges and corners (inside safe zones — see
patterns.md); menus sit inside an implied master frame (hairline rules, corner
brackets, or a letterboxed band). Nothing floats in undifferentiated space. If a
screenshot cropped to any corner doesn't hint at the style, the frame is missing.

### 5. Texture at whisper volume
Add exactly one ambient texture at 2–6% alpha over large fields: noise grain,
scanlines, grid, halftone, or diagonal stripes (per archetype). It must be invisible
when looked for and missed when removed. Pure flat #000/#111 expanses are the
loudest "web page" tell. Use CSS gradients or an inline SVG `feTurbulence` data URI
— never external image requests.

### 6. Typography does the heavy lifting
Four non-negotiables: (a) labels are small, uppercase, tracked (`letter-spacing:
0.1em+`) and dimmed; (b) hero numbers are huge and `tabular-nums`; (c) the jump
between type sizes is dramatic (≥2.5× label→value), not a gentle web-type scale;
(d) the game wordmark/logo is a designed lockup — an inline SVG mark, or text with
at least three deliberate treatments stacked (weight contrast, tracking, gradient
clip, layered shadow) — never a plain heading in the default stack. External font
requests are unavailable in self-contained pages: get display character from
condensed system stacks + tracking + weight, or embed a subsetted font as a data
URI when a distinctive face is truly load-bearing. Respect minimum sizes from
validations.md — drama comes from the top end, not shrinking labels.

### 7. Color discipline
Backgrounds are tinted, never neutral-gray (blue-black, warm-black, olive — per
archetype). One accent color does 80% of the accent work. Semantic colors (health
red, mana/shield blue, XP gold/green, warning amber) are *reserved* — never use
them decoratively, and never repurpose the accent as a semantic color. Avoid
framework defaults outright: #3b82f6 blue, Tailwind slate ramps, #10b981 green.

### 8. State changes are physical, not tonal
Web hover = slightly lighter background. Game hover/focus = something *happens*:
a bracket expands, an edge lights, a plate swaps polarity, a sheen sweeps. Keep
movement ≤2–4px (readability) but always change light or geometry, not just tint.
Selected states must be findable in a screenshot at arm's length.

### 9. Corner language is identity
Pick the archetype's corner treatment and apply it to 100% of containers: chamfer,
jag, notch, square, ornament, or slant. The default `border-radius: 8px` on
anything is an immediate web tell — round corners only in Minimal Ethereal (soft
variants) or touch-first casual UI, and then deliberately large (≥16px), not the
timid web default.

### 10. Iconography and ornament budget
No emoji as icons, ever — and no raw Unicode dingbats either (⚔ ▶ ✦ ◆ ⚗ as UI
icons): they render differently per platform, sometimes as color emoji, and always
read as placeholders. Use inline SVG line icons matching the stroke weight of the
archetype's borders; a 5-icon bespoke set beats a 50-glyph borrowed one. Cap
decoration: each panel gets at most two ornamental moves (e.g., corner diamond +
inner frame). More reads as clip-art fantasy; fewer reads as unstyled.

### 11. No native widgets
Native `<input type="range">`, checkboxes, `<select>`, and default scrollbars are
the loudest web-app tells in any options screen. Games use left/right steppers
(`◀ VALUE ▶` built from SVG or CSS triangles), notched custom sliders, and toggle
plates — all fully keyboard/controller operable (see patterns.md button mapping).
Style or hide scrollbars (`scrollbar-width`, `::-webkit-scrollbar`) inside the
fiction. Keep the native element in the DOM for accessibility where practical
(visually-hidden input driving a styled twin).

---

## Quick Self-Audit (run before delivering)

- [ ] Could a screenshot be mistaken for a SaaS dashboard? → re-apply rules 1, 3, 9.
- [ ] Is there any `border-radius: 4–12px`, default-blue, emoji/dingbat icon, or
      native form control? → remove (rules 7, 10, 11).
- [ ] Is the wordmark a designed lockup rather than a plain heading? (rule 6d)
- [ ] Do labels have tracking + uppercase, and heroes `tabular-nums` at ≥2.5× scale?
- [ ] Is there exactly one ambient texture, one accent hue, one angle value?
- [ ] Does focus/selection change geometry or light, not just background tint?
- [ ] Does any demo scaffolding leak into the fiction? Check specifically for:
      visible "placeholder" text; tabs/buttons that toggle a highlight but swap no
      content (dead tabs); debug hotkeys or dev toggles (e.g. "Reduce Motion Off",
      "Take hit H") listed in the gameplay HUD legend instead of a settings menu;
      inert settings that silently do nothing. → hide, move to a settings screen,
      or wire up.
- [ ] Is every font named in a `font-family` stack one that will actually resolve
      (a real system/web-safe face or an embedded data-URI face)? Naming a face you
      do not ship (e.g. "Rajdhani" with no @font-face) silently falls back and
      wastes the intended type identity. (rule 6d)
- [ ] Does it still pass validations.md (font minimums, contrast, color-only info)?
