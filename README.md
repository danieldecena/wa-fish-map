# WAFishMap

Native MapKit overlay of every WDFW marine area in Washington, plus the
statewide water-access launches and fishing piers.

Layer queries live in `WAFishMap/Models/MapScope.swift` — keep them there
rather than pasting `where=` strings into the view.

Overlays are geography, not the rulebook. Check Fish Washington before you fish.

## Quick start (Mac)

Needs **Xcode 26 or newer**: the chrome calls `glassEffect(_:in:)`, so the app
compiles against the iOS 26 SDK even though it still deploys to iOS 18.

```zsh
git clone git@github.com:danieldecena/wa-fish-map.git ~/developer/wa-fish-map
cd ~/developer/wa-fish-map
open WAFishMap.xcodeproj
```

Build and run on the iOS Simulator, or test from Terminal:

```zsh
# Run tests dynamically against the first available iPhone simulator
./scripts/run_sim.sh test
```

One check needs real hardware. WeatherKit mints its JWT from the provisioning
profile, which a Simulator build does not have, so the live wind and rain fetch
can only be observed on a device:

```zsh
./scripts/verify_weatherkit_device.sh
```

It refuses with the specific unblock if the iPhone is not attached, paired and
in Developer Mode, and otherwise runs the one XCUITest that asserts a live wind
speed is on screen.

See [SETUP.md](SETUP.md) for signing and troubleshooting.

## Troubleshooting empty Xcode navigator

If Xcode shows **Failed to open ContentView.swift** and the project tree is empty:

```zsh
cd ~/developer/wa-fish-map
zsh scripts/check_xcode_layout.sh
```

If sources are missing, restore from git:

```zsh
git checkout -- WAFishMap WAFishMapTests
```

If sources exist but Xcode is empty, quit Xcode and reset caches:

```zsh
rm -rf ~/Library/Developer/Xcode/DerivedData/WAFishMap-*
open WAFishMap.xcodeproj
```

Still broken? Recreate the project shell in Xcode (File → New → Project → iOS App,
name **WAFishMap**, save into this folder, SwiftUI + Swift Testing). Delete any
duplicate `WAFishMapApp.swift` / `ContentView.swift` stubs Xcode generates — keep
the ones already in `WAFishMap/`.

## What you get

- Fully statewide map covering 16 marine areas, plus rivers, lakes, and coastal areas.
- Live WDFW ArcGIS fetch with offline GeoJSON fallback for access sites and marine areas.
- Contextual streamflow (USGS), marine tides (NOAA), buoy data (NDBC), and plan-time weather (Apple WeatherKit).
- Swift Testing unit tests for parsers, scope filters, and model loading, plus
  XCUITest probes for the sheets and map chrome.

## Also in this repo: web pages

`Artifacts/` holds published companion pages built from the same data. They are
not part of the app, and the app never reads them:

- **Washington Fishing Map** (`Artifacts/salmon-rivers/`): recent SW Washington
  salmon reports, plus a Typical season mode that rates ~540 statewide sites
  with a JS port of the app's own rating. Its Seasons layer, the former
  Washington Fishing Year page (October 2026 to November 2027), is built from
  `Artifacts/salmon-rivers/seasons/seasons.json`.
- **SW Washington Creel Table** (`Artifacts/salmon-catch-table/`): WDFW weekly
  creel counts.
- The WA Fish Map design system (`Artifacts/design-system/`) and the one-map
  design canvas (`Artifacts/one-map-layers-design/`).
- `Artifacts/archive/`: retired and older pages, kept with their published
  source: the Washington Fishing Year and Three Friends Fishing Hole pages (now
  layers of the map), the App Store listing and its interactive preview, and the
  "Inside WAFishMap" explainer.

Each folder's README covers how to refresh, test and publish it. Node tests:

```zsh
node --test "Artifacts/salmon-rivers/test/*.test.js"
```
