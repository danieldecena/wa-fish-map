# Motion spec for the Washington Fishing Map page

Date: 2026-10-29. Page: `Artifacts/salmon-rivers/index.html`. Tests: `Artifacts/salmon-rivers/test/motion.test.js` and the motion checks in `Artifacts/salmon-rivers/check-week.mjs`.

The motion was designed in Figma first, on a new page named Motion in the WA Fish Map component library
(file `ribqki97SaOhwvwyOsRIj2`, page id `23:175`), then implemented on the real page. The Figma frames are built from instances of the library
components (Rating Badge, Glass Card, Layer Toggle, Site Marker) and are bound to the library's colour, radius and spacing variables.
Screenshots of the six frames (resting state, which is all `get_screenshot` shows) are in `docs/design/motion/`.

## Tokens

The Motion collection is `VariableCollectionId:21:175` (one mode, `Value`). Web code syntax is set on every variable. The page declares the same names on `:root`.

| Figma variable | Id | Type | Value | CSS property |
|---|---|---|---|---|
| `dur/fast` | `VariableID:21:176` | FLOAT | 120 | `--dur-fast: 120ms` |
| `dur/base` | `VariableID:21:177` | FLOAT | 200 | `--dur-base: 200ms` |
| `dur/slow` | `VariableID:21:178` | FLOAT | 280 | `--dur-slow: 280ms` |
| `dur/camera` | `VariableID:21:179` | FLOAT | 400 | `--dur-camera: 400ms` (the camera's midpoint; see Camera) |
| `dur/pop` | `VariableID:21:180` | FLOAT | 160 | `--dur-pop: 160ms` (added: popover in, pin lift, switch) |
| `dur/layer` | `VariableID:21:181` | FLOAT | 240 | `--dur-layer: 240ms` (added: heat circles and depth lines) |
| `dur/pulse` | `VariableID:21:182` | FLOAT | 450 | `--dur-pulse: 450ms` (added: pin ring) |
| `ease/out` | `VariableID:21:183` | STRING | `cubic-bezier(.2,.8,.2,1)` | `--ease-out` |
| `ease/in` | `VariableID:21:184` | STRING | `cubic-bezier(.4,0,1,1)` | `--ease-in` |
| `ease/inout` | `VariableID:21:185` | STRING | `cubic-bezier(.65,0,.35,1)` | `--ease-inout` |
| `easing/out` | `VariableID:22:178` | EASING | custom cubic bezier .2 .8 .2 1 | (Figma only; keyframes alias it) |
| `easing/in` | `VariableID:22:179` | EASING | custom cubic bezier .4 0 1 1 | (Figma only) |
| `easing/inout` | `VariableID:22:180` | EASING | custom cubic bezier .65 0 .35 1 | (Figma only) |

The four durations and three easings the brief named are the FLOAT and STRING variables. The three `dur/pop`, `dur/layer` and `dur/pulse` rows are additions, because 160, 240 and 450 ms recur and had no token.
`--ease-inout` is declared for parity but no rule uses it: the camera applies a true ease-in-out cubic in JavaScript, which is the curve it is named for.

What is bound, and what cannot be: keyframe easing is a variable alias (`easing/out` or `easing/in`) on every keyframe that eases, so the easing in the Figma file follows the variable. Keyframe
positions are seconds and cannot be bound to a variable, so the FLOAT `dur/*` variables document the numbers but do not drive the timelines. The colour keyframes of the switch track are raw colours resolved from `fill/tertiary` and `chrome/rivers-on`, not bindings.

## The six motions

Frames are top-level frames on the Motion page; each has a 2 s timeline that loops in Figma (the timeline default; see Limits). Node ids are the nodes that carry keyframes.

| Motion | Figma frame | Animated nodes | Trigger | Duration and easing | Properties | Reduced motion |
|---|---|---|---|---|---|---|
| A. Sheet enter and exit | `23:176` | wide sheet `23:182`, phone sheet `23:195`, blocks `23:183` `23:184` `23:187` `23:190` `23:191` (wide) and `23:196` `23:197` `23:200` `23:201` (phone) | A pin, river, spot or list opens the sheet (`showSheet`); Done or Esc closes it | In 280 ms ease/out (`--dur-slow`); out 200 ms ease/in (`--dur-base`). Blocks rise 200 ms ease/out, starting 80 ms after the open, 40 ms apart | Sheet: translateX (wide, from the right) or translateY (phone, from the bottom). Blocks: opacity 0 to 1 and translateY 8 px to 0 | No transition, no rise: the sheet jumps, as before |
| B. Popover open and close | `24:181` | popover `24:189` (button `24:187`) | A bar button opens or closes Layers, Species, Key, the notice, the phone mode menu or My location | In 160 ms ease/out (`--dur-pop`); out 120 ms ease/in (`--dur-fast`) | opacity 0 to 1, scale .96 to 1, origin at the button | No transition, no exit copy |
| C. Pin select | `24:215` | ring `24:219`, selected marker `24:220` (idle marker `24:228` is the control) | A pin becomes the open sheet's site | Ring 450 ms ease/out (`--dur-pulse`); lift 160 ms ease/out; settle back 120 ms ease/in | Ring: opacity .6 to 0 and scale .6 to 1.8 once. Pin: translateY 0 to -2 px | None: no ring, no lift |
| D. Disclosure expand | `25:201` | card `25:205`, chevron `25:210`, body `25:212`, next card `25:218` | A `details` element (species row, "How this is worked out", Notes) opens or closes | Open 200 ms ease/out (`--dur-base`); close 120 ms ease/in (`--dur-fast`) | Content height 0 to auto (`details::details-content`), chevron rotate 90 degrees, the rows below move with it | Instant, as before |
| E. Heat and depth layers on | `25:255` | heat circles `25:259` to `25:266`, depth lines `25:267` to `25:269` | The Heat or Depth layer turns on (or the map zooms in to where they draw) | 240 ms ease/out (`--dur-layer`). Heat circles wait 30 ms per 50 px from the map centre, capped at 150 ms | Heat circles: opacity and scale .8 to 1. Contours: opacity | None |
| F. Layer switch | `25:392` | track `25:401`, knob `25:402` (idle Heat row `25:408` is the control) | A row in the Layers menu is toggled | 160 ms ease/out (`--dur-pop`), both ways | Knob translateX 16 px; track colour off to on | None (the old 150 ms knob transition is now inside the no-preference block too) |

The camera is not a Figma frame: it is the map pan and zoom (`animateTo`), covered below.

### Camera

`dur/camera` (400 ms) is the nominal figure. In the page the duration scales with the trip, because a 400 ms flight is slow for a nudge and abrupt across the state.

| Travel (px on screen; one zoom octave counts as 100) | Duration |
|---|---|
| 0 | 280 ms |
| 800 | 400 ms (`--dur-camera`) |
| 1600 and more | 520 ms |

`camMs` computes `280 + travel * 0.15` and clamps it to 280 to 520 ms. The curve is a cubic ease in and out (`4k^3` below .5, then `1 - (-2k + 2)^3 / 2`), which is the previous ease-out cubic made soft at the start as well. A visitor who asked for reduced motion still gets the view set at once (`if (reduce) { setView(t); return; }`, unchanged).
The callers no longer pass a duration; the eight fixed `320` and `350` values are gone.

## What `get_motion_context` returned

Called with `recursive: true` on each of the six frames, asking for CSS. Every node that has keyframes came back with a CSS snippet and a motion.dev snippet; every `timelineCohorts` entry that came back (frames A, C, D, E, F; B has one animated node, so none) says `loopMode: "loop"`, `durationMs: 2000`. Line breaks below are mine; the declarations are as returned.

Observations that matter for the page:

- It emits CSS individual transform properties (`translate`, `scale`), not `transform`, and the chevron through an `@property --rotate-transform` angle. The page uses `translate`/`scale` where it can and `transform: scale()` / `translateY()` inside keyframes.
- The easing sits on the keyframe that starts each segment (`animation-timing-function` on the `%` stop), as CSS wants it. The variable aliases (`easing/out`) were resolved to `cubic-bezier(0.2, 0.8, 0.2, 1)`, so the output carries the numbers, not the variable name.
- `HOLD` became `animation-timing-function: step-end` (the ring's opacity step).
- `transform-origin` is not in the CSS. Figma scales about the node's centre, so the popover's "origin at the button" had to be built as a scale plus a compensating translate in Figma, and the CSS reproduces that. The page does not copy it (see Changes).
- Percentages are of the whole 2 s timeline, so every duration has to be read back from them: 0 to 14% of 2 s is the 280 ms slide.

### A. Sheet (wide: `23:182`; phone `23:195` is the same on the Y axis with 180 px)

```css
animation: kf_23_182_translate_0 2s linear; animation-iteration-count: infinite;
@keyframes kf_23_182_translate_0 {
  0% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); translate: 400px 0px; }
  14% { translate: 0px 0px; }
  50% { animation-timing-function: cubic-bezier(0.4, 0, 1, 1); translate: 0px 0px; }
  60% { translate: 400px 0px; }
  100% { translate: 400px 0px; }
}
```

First content block (`23:183`; blocks 2 to 5 are the same shifted by 40 ms, starts at 6%, 8%, 10%, 12%):

```css
animation: kf_23_183_opacity_0 2s linear, kf_23_183_translate_0 2s linear; animation-iteration-count: infinite;
@keyframes kf_23_183_opacity_0 { 0% { opacity: 0; } 4% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); opacity: 0; } 14% { opacity: 1; } 100% { opacity: 1; } }
@keyframes kf_23_183_translate_0 { 0% { translate: 0px 8px; } 4% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); translate: 0px 8px; } 14% { translate: 0px 0px; } 100% { translate: 0px 0px; } }
```

### B. Popover (`24:189`)

```css
animation: kf_24_189_opacity_0 2s linear, kf_24_189_translate_0 2s linear, kf_24_189_scale_0 2s linear; animation-iteration-count: infinite;
@keyframes kf_24_189_opacity_0 { 0% { opacity: 0; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); opacity: 0; } 18% { opacity: 1; } 60% { animation-timing-function: cubic-bezier(0.4, 0, 1, 1); opacity: 1; } 66% { opacity: 0; } 100% { opacity: 0; } }
@keyframes kf_24_189_translate_0 { 0% { translate: 6px -3.8px; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); translate: 6px -3.8px; } 18% { translate: 0px 0px; } 60% { animation-timing-function: cubic-bezier(0.4, 0, 1, 1); translate: 0px 0px; } 66% { translate: 6px -3.8px; } 100% { translate: 6px -3.8px; } }
@keyframes kf_24_189_scale_0 { 0% { scale: 0.96 0.96; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); scale: 0.96 0.96; } 18% { scale: 1 1; } 60% { animation-timing-function: cubic-bezier(0.4, 0, 1, 1); scale: 1 1; } 66% { scale: 0.96 0.96; } 100% { scale: 0.96 0.96; } }
```

### C. Pin select (ring `24:219`, marker `24:220`)

```css
animation: kf_24_219_opacity_0 2s linear, kf_24_219_scale_0 2s linear; animation-iteration-count: infinite;
@keyframes kf_24_219_opacity_0 { 0% { animation-timing-function: step-end; opacity: 0; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); opacity: 0.6; } 32.5% { opacity: 0; } 100% { opacity: 0; } }
@keyframes kf_24_219_scale_0 { 0% { scale: 0.6 0.6; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); scale: 0.6 0.6; } 32.5% { scale: 1.8 1.8; } 100% { scale: 1.8 1.8; } }
/* marker 24:220 */
@keyframes kf_24_220_translate_0 { 0% { translate: 0px 0px; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); translate: 0px 0px; } 18% { translate: 0px -2px; } 70% { animation-timing-function: cubic-bezier(0.4, 0, 1, 1); translate: 0px -2px; } 76% { translate: 0px 0px; } 100% { translate: 0px 0px; } }
```

### D. Disclosure (card `25:205`, chevron `25:210`, body `25:212`, next card `25:218`)

```css
@keyframes kf_25_205_height_0 { 0% { height: 44px; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); height: 44px; } 20% { height: 152px; } 60% { animation-timing-function: cubic-bezier(0.4, 0, 1, 1); height: 152px; } 66% { height: 44px; } 100% { height: 44px; } }
@property --rotate-transform { syntax: '<angle>'; initial-value: 0rad; inherits: false; }
transform: rotate(var(--rotate-transform, 0rad));
@keyframes kf_25_210_rotate_0 { 0% { --rotate-transform: 0rad; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); --rotate-transform: 0rad; } 20% { --rotate-transform: 1.571rad; } 60% { animation-timing-function: cubic-bezier(0.4, 0, 1, 1); --rotate-transform: 1.571rad; } 66% { --rotate-transform: 0rad; } 100% { --rotate-transform: 0rad; } }
@keyframes kf_25_218_translate_0 { 0% { translate: 0px 0px; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); translate: 0px 0px; } 20% { translate: 0px 108px; } 60% { animation-timing-function: cubic-bezier(0.4, 0, 1, 1); translate: 0px 108px; } 66% { translate: 0px 0px; } 100% { translate: 0px 0px; } }
```

### E. Heat circle 1 (`25:259`, no delay) and Depth line 1 (`25:267`, 57 ms); the others differ only in their start percentage

```css
animation: kf_25_259_opacity_0 2s linear, kf_25_259_scale_0 2s linear; animation-iteration-count: infinite;
@keyframes kf_25_259_opacity_0 { 0% { opacity: 0; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); opacity: 0; } 22% { opacity: 0.7; } 65% { animation-timing-function: cubic-bezier(0.4, 0, 1, 1); opacity: 0.7; } 71% { opacity: 0; } 100% { opacity: 0; } }
@keyframes kf_25_259_scale_0 { 0% { scale: 0.8 0.8; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); scale: 0.8 0.8; } 22% { scale: 1 1; } 100% { scale: 1 1; } }
```

Start percentages of the other circles (10% is t = 0.2 s): circle 2 and 3 12.35% (47 ms), 4 14.04%, 5 14.33%, 6 16.445%, 7 16.51%, 8 17.5% (150 ms, the cap); depth lines 12.865%, 10.575%, 12.03%. The motion.dev output for the depth lines is a `motion.svg`.

### F. Switch track `25:401` and knob `25:402`

```css
animation: kf_25_401_background-color_0 2s linear; animation-iteration-count: infinite;
@keyframes kf_25_401_background-color_0 { 0% { background-color: #ECECED; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); background-color: #ECECED; } 18% { background-color: #007C9E; } 60% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); background-color: #007C9E; } 68% { background-color: #ECECED; } 100% { background-color: #ECECED; } }
@keyframes kf_25_402_translate_0 { 0% { translate: 0px 0px; } 10% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); translate: 0px 0px; } 18% { translate: 16px 0px; } 60% { animation-timing-function: cubic-bezier(0.2, 0.8, 0.2, 1); translate: 16px 0px; } 68% { translate: 0px 0px; } 100% { translate: 0px 0px; } }
```

## What the page does that the Figma output does not, and why

| Where | Figma output | Page | Why |
|---|---|---|---|
| Loop | `animation-iteration-count: infinite` on every node | Plays once per trigger | The timeline loops only so the frame can be previewed; a sheet that re-opened itself every 2 s would be absurd. |
| Popover origin | scale about the centre plus a (6 px, -3.8 px) translate | `transform-origin` at the button's centre (`--pop-ox`, set when the panel opens), plain scale | The panel is positioned by the bar, so the button's x is only known at runtime. The compensating translate was needed only because Figma cannot set an origin. |
| Popover as keyframes | keyframes in and out | Open is a CSS transition from `@starting-style`; close plays an animation on a copy | `[hidden]` is `display: none !important` on the published page (the wrapper's rule), so a transition cannot run on close. The copy has no ids, is `aria-hidden` and `inert`, and is removed on `animationend` (or after 400 ms). The real panel is `hidden` at once, so every existing check and caller sees the state they did before. |
| Sheet blocks | start at 80 ms, 40 ms apart, five blocks | Same: blocks 1 to 5 start at 80, 120, 160, 200, 240 ms; the sixth and every later block start together at 280 ms | A long sheet (creel, notes) has 10 or more blocks; a stagger that ran to 400 ms would feel slow. |
| Sheet exit | blocks stay still | Same | Only the sheet moves on exit, so the exit stays at 200 ms. |
| Pin | ring and lift on the marker instance | Ring and lift on `.pin` pins (every report, typical and spawning pin). Spot-guide pins are not animated | Spot guides do not take part in the "selected" state (`selected` is the site id). The lift is on `.pin-s`, never on the `<g class="pin">` whose `transform` is rewritten on every pan. |
| Disclosure chevron | rotates | Rotates on `details.how` only | `details.sp` and `details.srcs` have no chevron on the page, and the brief says to leave the sheet content alone. |
| Disclosure rows below | move by a keyframe | Move with the document flow | The height of `::details-content` changes, so the rows below follow without a second animation. |
| Heat and depth off | 120 ms fade | Not animated: the circles and the contour group are removed | They are rebuilt from scratch on every tick (circles) or removed from the DOM (contours), so there is nothing left to fade. The design shows the fade; it is not built. |
| Depth lines | fade and scale from .8, staggered | Fade only, whole group at once | The contour group carries the map's scale as an attribute transform; a CSS scale on it would replace that and misplace every contour. |
| Heat stagger | by distance from the Figma stage centre | by distance from the map's screen centre, set only when the layer turns on (the SVG was empty) | A circle that scrolls into view during a pan must not fade in late. |
| Switch off colour | `#ECECED`, opaque | the page's `--fill-toggle` (14% grey, translucent) | With a translucent first keyframe (alpha .12) `get_screenshot` drew the track as solid dark grey, and the track's `baseValue` read back with alpha 1. I did not establish which of the two is right, so the design uses an opaque colour (the page's grey over white) and the page keeps its own translucent token. |
| Camera | not designed | distance-scaled 280 to 520 ms, ease in and out | See Camera. |

Everything above sits inside `@media (prefers-reduced-motion: no-preference)` except the pin ring's resting style (`opacity: 0`), which draws nothing. `riseIn`, the heat delay and `--pop-ox` run for every visitor but only set a class, a delay or a custom property that no rule reads under `reduce`.

## Limits of the tools, as met

- `get_motion_context` returns CSS and motion.dev, always looping, with no `transform-origin`, no variable names (aliases come back as numbers) and all times as percentages of the timeline. The durations, the stagger table and the reduced-motion behaviour are not in it; they are in this file because they had to be written by hand.
- Keyframe positions and the `dur/*` FLOAT variables cannot be bound to each other. Only easing can be a variable (an `EASING`-type variable, aliased from the keyframe).
- I found no `transform-origin` in the motion API the skill documents; scale and rotation pivot about the node's centre.
- Animating `HEIGHT` is allowed only for a positive value and not for groups or vectors; the disclosure card is a frame.
- Applying a fills track needs the `manualKeyframeTracks.fills` assignment form; `applyManualKeyframeTrack` with a `field` for fills is rejected.
- `get_screenshot` shows the resting (base) state only. The ring in frame C and the switch track in frame F show their base values, not t = 0. Motion was not rendered to video; the numbers were checked by reading the keyframes back and by running the page.
