# Screens

Six frames captured from the iPhone 18 Pro simulator on 2026-09-20, after the
marker-sizing change. They are the reference for how the tokens compose in the
real product — regenerate them with `scripts/app_store_screenshots.sh`, which
takes all six in one run.

| Frame | What it is for |
| --- | --- |
| `01-map-regional` | Pin scale, clustering, place labels, the floating chrome. The frame the marker-size decision was made on. |
| `02-site-detail-guidance` | A launch sheet end to end: rating badges, species rows, size silhouettes, "Before you go". |
| `03-pier-detail` | The pier sheet. Every sheet has to carry the disclaimer and the WDFW link — this is the observation, not the assumption. |
| `04-river-detail` | The river sheet, same check. |
| `05-map-regional-dark` | The ramp against a dark basemap. |
| `06-site-detail-dark` | The ramp against a dark sheet. |

The sheets come from the UI-test seam (`-uiTesting -planMonth 8`,
`-uiTestingDetail pier|river`), not from tapping pins — a clustered map is the
moving target that seam exists to avoid.

**Read the dark pair closely.** The four rating colours are hardcoded RGB in
`ColorRamp.swift` and do not follow the appearance, so these two frames are the
only place that decision is visible. The `rating-*-system` tokens are the fix.

`01` frames the Columbia around Vancouver rather than Puget Sound: a freshly
installed build had not taken the simulated location fix before the shot. The
camera choice is data, not design — reshoot if you want a Sound framing.
