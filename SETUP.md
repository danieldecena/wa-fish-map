# WAFishMap — Mac setup

The repo ships a complete `WAFishMap.xcodeproj` (file-system synchronized
groups). Open and build — no manual project creation needed.

Needs **Xcode 26 or newer**. `GlassCard` calls `glassEffect(_:in:)` behind an
`if #available(iOS 26.0, *)`, and `#available` is a runtime gate, not a
compile-time one — the compiler still has to find the symbol in the SDK it
builds against. On Xcode 16 the build fails outright with "value of type
'GlassCard.Content' has no member 'glassEffect'". The deployment target stays
iOS 18, which is what the material fallback is for.

## Clone and build

```zsh
mkdir -p ~/developer
cd ~/developer
git clone git@github.com:danieldecena/wa-fish-map.git
cd wa-fish-map
open WAFishMap.xcodeproj
```

In Xcode: select the **WAFishMap** scheme, pick an iPhone simulator (or your USB
device), press Run.

Or from Terminal:

```zsh
cd ~/developer/wa-fish-map
# Run tests dynamically against the first available iPhone simulator
./scripts/run_sim.sh test
```

### Test plans

The scheme links two plans:

- `WAFishMap.xctestplan` (default): `WAFishMapTests` and `WAFishMapUITests`, the
  same tests the scheme ran before it had plans. `⌘U` and
  `./scripts/run_sim.sh test` use it.
- `WAFishMapUnit.xctestplan`: the unit bundle only, so a CI Test action can gate
  on the logic tests without also running the UI probes.

```zsh
xcodebuild -scheme WAFishMap -showTestPlans          # lists WAFishMap and WAFishMapUnit
```

To run just the unit plan, pass `-testPlan WAFishMapUnit` to the same
`xcodebuild … test` command that `scripts/run_sim.sh` runs.

Both plans have to be listed explicitly. Linking only the unit plan beside the
scheme's automatic one leaves the automatic plan empty, and the default run then
fails with "There are no test bundles available to test" (seen 2026-10-07).

Choosing the plan in the Xcode Cloud workflow's Test action is a separate step in
Xcode / App Store Connect. Apple's test-plan documentation does not cover it, so
it has not been checked.

## Run it on a simulator

```zsh
cd ~/developer/wa-fish-map
scripts/run_sim.sh
```

Resolves a device the way CI does (booted one if there is one, else the newest
available iPhone), builds, installs, sets a simulated fix inside Marine Area 11,
and launches. `--shot out.png` also screenshots; `-l lat,lon` moves the fix;
`--no-location` leaves the app on its statewide framing.

The location matters. The camera opens auto-fit and only eases to a regional
span on a first fix **inside the Washington bbox**; a fresh simulator has no
fix at all, so without one you never exercise that path.

### Seeing a stale build?

`xcrun simctl launch` runs whatever is installed — it never builds. So a failed
or skipped `xcodebuild` leaves the previous copy on the device and launching
"succeeds" into the old app. Same for a simulator left booted from an earlier
session. When in doubt, clear both ends:

```zsh
git pull                                    # the clone itself can be behind
xcrun simctl uninstall booted com.danieldecena.WAFishMap
rm -rf /tmp/wafishmap-dd ~/Library/Developer/Xcode/DerivedData/WAFishMap-*
scripts/run_sim.sh
```

## Signing (device only)

Set **Signing & Capabilities → Team** on the WAFishMap target. Simulator builds
need no team.

## Broken scratch project?

If you have an empty bundle at `~/Tools/scratch-WAFishMap-discard/WAFishMap.xcodeproj`,
delete it and use this repo instead:

```zsh
rm -rf ~/Tools/scratch-WAFishMap-discard
```

## Verify WDFW live data (optional)

```zsh
python3 scripts/verify_wdfw_live.py
```

## Scripts

Each script's own header is the reference; this is the index. The generators
write bundled resources, so run one, look at the diff, and commit the result.
Never hand-edit a generated file.

| Script | What it does |
|--------|--------------|
| `scripts/run_sim.sh` | Build, install and launch on a resolved simulator; `test` runs the default plan. |
| `scripts/check_xcode_layout.sh` | Diagnose an empty Xcode navigator (see README). |
| `scripts/app_store_screenshots.sh` | Capture App Store screenshots from a booted simulator with the app installed. |
| `scripts/build_lakes.py` | Generate `WAFishMap/Resources/lakes.json` from WDFW's lowland lakes map. |
| `scripts/build_rivers.py` | Generate `WAFishMap/Resources/rivers.json` from USGS NHD flowlines. |
| `scripts/build_river_stats.py` | Generate `WAFishMap/Resources/river_stats.json`, each river's own flow history. |
| `scripts/build_web_data.py` | Build `site/data/` for the web demo (`docs/web-demo-spec.md`) from WDFW's live service. |
| `scripts/verify_wdfw_live.py` | Validate the statewide WDFW contract the app depends on. |
| `scripts/verify_river_stats.py` | Check every gauged river's flow colour against USGS. |
| `scripts/verify_weatherkit_device.sh` | Run the one WeatherKit test that needs a physical device. |
| `scripts/weatherkit_rest_probe.py` | Ask WeatherKit over REST, as a control on a device-side 401. |
| `scripts/testflight_internal.py` | Diagnose, and with `--apply` create, the internal TestFlight tester chain. Read-only without `--apply`. |
| `scripts/cvd_check.py` | Simulate colour-vision deficiency over the pinned rating-ramp frames. |
| `scripts/make_icon.swift` | Draw the app mark and emit both the flat PNG and the layered `.icon` bundle. |

These feed the web pages in `Artifacts/`, not the app. Run them with
`/opt/homebrew/bin/python3`; each page's README has the full refresh order.

| Script | What it does |
|--------|--------------|
| `scripts/build_typical_sites.py` | Write `Artifacts/salmon-rivers/typical.js` (Typical season snapshot) from `site/data/sites.json` and `fisheries.json`; `--refresh` refetches WDFW marine areas. |
| `scripts/build_creel_sites.py` | Write `Artifacts/salmon-rivers/creel.js` from WDFW's Puget Sound creel page, matched through `scripts/creel_crosswalk.json`; also rewrites the creel review note in `docs/research/`. |
| `scripts/creel_crosswalk.json` | Reviewed WDFW ramp → map site matches. Only `high` entries apply; `medium` ones wait for Daniel's approval. |
| `scripts/build_salmon_db.py` | Build `~/database/salmon-rivers/salmon.db` from WDFW's weekly SW Washington reports; `--fetch` downloads new PDFs first. |
| `scripts/build_salmon_counts.py` | Write `Artifacts/salmon-rivers/counts.js` from `salmon.db`. |
| `scripts/export_salmon_page.py` | Write `Artifacts/salmon-catch-table/data.js` from `salmon.db`; refuses if a row count disagrees. |
| `scripts/build_fishing_year.py` | Write `Artifacts/fishing-year/data.js` from `seasons.json`; `--check` validates only. |
| `scripts/test_*.py` | Unit tests for the scripts above: `/opt/homebrew/bin/python3 -m unittest discover -s scripts -p "test_*.py"`. |
