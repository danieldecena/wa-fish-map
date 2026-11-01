# Design critique: Washington Fishing Map, version 37 (2026-10-27)

Captures: the repo's `Artifacts/salmon-rivers/` at main 9257922 with the live `geo.js`
from version 1793089848-ed42 (the repo's differs in a few river lines), served with the
publisher's wrapper, `?today=2026-10-27`, headless Chromium. Sizes: 390x844, 360, 320
(from `check-week.mjs --shots`), 1024x768, 1280x800, 1366x768, 1440x900, 1920x1080.
Positions are measured from the DOM. Fixed constraints (not findings): the rating ramp,
the guidance-not-regulation lines, the WDFW links. The 2026-10-26 critique's seven fixes
all still hold.

## Overall read

Phones are in good shape: the bar fits, the Key shows, report pins and labels are clear,
and the sheets read well (name, one rating chip, Directions, What's biting with dated
chips, then the creel week). The main problem is on laptop-sized windows: the opening
view of Recent reports cuts off most of the reported rivers, and Reset view does not
bring them back.

## Findings, ranked by user impact

### 1. Laptop windows open with most report rivers off the bottom (Reports)
- Measured: at 1280x800, 3 of 7 report pins are on screen; Lewis, Kalama, Klickitat
  and Washougal sit below the bottom edge (y 809 to 898). At 1024x768, Washougal is off
  (y 775). Reset view gives the same result. 1440x900, 1920x1080 and phones are fine.
- Cause: `homeFit()` asks for scale 1.649 at 1280x800 (1.549 at 1024x768), but
  `limits()` sets the Reports zoom floor to 0.9 x the unpadded whole-state fit (2.028 and
  1.664). `setView`/`animateTo` raise `t.s` to that floor without moving `tx`/`ty`, so the
  map grows down and right from the fitted origin.
- Fix: in `limits()`, keep the floor at or below the home view:
  `minS = Math.min(home, homeFit().s) * 0.9`. Separately, when the scale is clamped, keep
  the map-space centre (compute it before clamping, as `animateTo` already does).
- Assertion: at 1280x800 and 1024x768 in Reports, every `#over .pin[aria-label]` centre
  is inside the window below the bar, on load and after `#zfit`.

### 2. Phone summary chips run off the card with no cue (Reports)
- Measured at 390: the `.dsum` row scrolls (700 px of content in 348). "2 seasons open"
  is cut at the edge ("2 seas"), and "65 spawning" and "8 prime-season sites" are fully
  hidden, with no fade or arrow.
- Fix: wrap the row on phones (`flex-wrap: wrap`) so all four chips show, or add a
  right-edge fade when `scrollWidth > clientWidth`.
- Assertion: at 390, every `.dsum` button's right edge is inside `#smonth`.

### 3. Month names touch at 360 px (Reports, months open)
- `check-week.mjs` fails "the twelve month names keep a 1px gap (touching: Jun)" at 360,
  light and dark. Version 36 fixed this on the Mac. Here the browser has no SF Pro, so the
  fallback font is wider: a real risk on Android and Windows rather than on iPhone.
- Fix: below 380 px, use single-letter or three-letter month labels in a smaller size,
  or let the row drop every other label.

### 4. A dashed season circle has no label (Seasons layer, phones)
- Seen at 390 with the default layers: a dashed circle over Hood Canal draws without a
  name, while the Skagit season nearby reads "Skagit coho · ends Oct 31".
- Fix: give each season's place mark a label (the season name), dropping it only when
  it would collide.

### 5. Desktop wastes the left half on open ocean at 1440x900 (Reports)
- Seen: the opening view anchors the box bottom-right, so the Pacific fills the left
  half under the card while Klickitat's label is cut at the right edge.
- Fix: comes with finding 1. Fit the report rivers into the area right of and below the
  card, and keep a label margin on the right.

### 6. Spot-guide group labels sit tight against their badges (Spot guides layer)
- Seen at 390: "3 spot guides" starts against the "3" badge, and the "2" group near
  Olympia touches the 3-group's pin. Readable, but crowded.
- Fix: offset group labels by the badge width plus 4 px.

## Content note (not design)

Every report is over a week old (newest Oct 17), so every report pin is dashed. The page
says so honestly. The fix is fresher reports (the Puget Sound sourcing task in TASKS.md),
not a design change.

## What works and should stay

- Sheets: clear order, one rating chip, honest "Release only" and dated chips, and the
  WDFW creel week right under What's biting.
- The phone bar: six 44 px controls, Key visible, report-age line under the bar.
- Dark mode: muted basemap with readable rivers, pins and labels.
- Grouped guide pins with a chooser and "Zoom in here" (version 37).
