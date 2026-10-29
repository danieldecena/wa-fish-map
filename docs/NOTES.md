# Pipeline Retro: salmon rivers page, 2026-10-18

Run: plan (`docs/superpowers/plans/2026-10-18-salmon-rivers-artifact.md`), design critique, six implementation tasks with per-task review, a final whole-branch review, one fix wave, publish, PR 53.

## What slowed this run down

- The browser preview tool could not find `.claude/launch.json` from the session folder, so every implementer had to be told to start `serve.js` with Bash and drive the browser pane by URL. The plan said otherwise and was wrong.
- The plan went in before the live page had been looked at. The design critique came after it and found that pin labels never displayed, which made Task 4 as first written do nothing. The plan had to be rewritten.
- The plan's numbers were estimates (one contrast figure was 6.5:1 and measured 5.97:1; the brief's teal measured 4.3:1 on the map). Each cost a review finding or a fix round.
- Review packages built from raw git ranges included two 400+ KB generated files; the controller had to build trimmed diffs by hand twice.

## What required a guess instead of a clear decision

- "do for species we have on wa-fish-map" was ambiguous (a species-aware page from app data, or species chips on the catch-report page). The question offered no marked recommendation, and the answer was "recommended". The controller chose to finish the salmon plan first and plan species separately. The species request is still open.
- Which Guide's Forecast report dates the Columbia Chinook sentence. Left as "Date not given".
- Whether "finalize" meant the project-finalize pipeline step or just wrapping up. It was read as wrapping up this work: a page README, this retro, and the final commit.

## What should change next time

- Look at the live page (screenshots at phone and desktop width, light and dark) and run the contrast and colour-blind numbers before writing a plan, not after.
- Put measured values in plans, and name the verification tool that actually works in this environment.
- Enumerate every surface that a constraint binds. "On every river sheet" missed the new list sheet; the final review caught it.
- DOM behaviour has no automated test, and that is how the hidden-label bug shipped. If label placement changes again, pull it into a pure `placeLabels()` function in its own module and test it in Node.
- Have a standard way to build a review package that skips generated files.
- When a question to the user offers options, mark which one is recommended.

## Bug patterns worth remembering

- A collision box for a child (label) that starts inside its parent's own box hides the child everywhere. Check strict versus loose overlap at the shared edge.
- Measuring an SVG text node with `getBBox` needs it displayed; setting `display = ''` temporarily is safe only if every caller re-renders straight after.
- A colour that passes on white can fail on the map ground (`#f2f2f7`): check text colour against the surface it actually sits on.
- Tokens used for text and for fills should be separate (`--on-text` versus `--on`), because dark mode needs a lighter text value than fill value.
- Hiding information while a sheet is open (the legend, the banner) can remove the only disclaimer on screen.
- A statement added between a one-line `if (...) x;` and the `else` on the next line steals the `else` (2026-10-29, marine focus: Typical pins fell into the Spawning label branch and `render` threw). Wrap the `if` in braces before inserting, and look at a Typical season pin with another pin in view, not only the focused ones.

## Subagent memory

None of the subagents in this run had `memory: project` or `memory: user` configured, so nothing needed saving.
