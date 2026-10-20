# Where Salmon Spawn (superseded)

The standalone page "Where Salmon Spawn", published once (v1, version `1792487132-62ab`) on 2026-10-20: 75 salmon viewing sites from WDFW's Salmon Viewing list on a Washington map, coloured by typical spawning timing for a chosen month.

**Superseded** the same day by the Spawning mode of the Washington Fishing Map app (`Artifacts/salmon-rivers`, open it with `?mode=spawning`). Make changes there, not here. This folder keeps the published v1 so the live link has its source, as every fish artifact must (see CLAUDE.md, "Web pages"). The one change still planned is a banner on this page pointing to the app (`TASKS.md`).

Live: https://claude.ai/artifact/F5zGNo3kKd2333Ggr9iQmX (binding in `artifact.json`).

| File | What it is |
| --- | --- |
| `index.html` | The page as published, with the publisher's wrapper (captured from the live artifact). |
| `sites.js` | The 75 sites, from the session script `build_sites.py` (not in the repo). Its v1 species names are short forms (Coho, Chinook) and do not meet the app's exact-name rule; the app's `sites.js`, from `scripts/build_spawning_sites.py`, does. |
| `rivers.js`, `coast.js` | Basemap rivers and coastline in the same projection as the app's `geo.js`. Generated in the publishing session; the generator is not in this repo. |
| `cluster.js` | Grid pin clustering (the app's `cluster.js` without `look`). |

Typical timing, not a guarantee and not regulation, as on the page.
