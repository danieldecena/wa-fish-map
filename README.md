# WAFishMap

Native MapKit overlay of WDFW Marine Area 13 (South Puget Sound) plus
Thurston County water-access launches.

Widen the slice by editing `WAFishMap/Models/MapScope.swift` only.

Overlays are geography, not the rulebook. Check Fish Washington before you fish.

## Quick start (Mac)

```zsh
git clone git@github.com:danieldecena/wa-fish-map.git ~/developer/wa-fish-map
cd ~/developer/wa-fish-map
open WAFishMap.xcodeproj
```

Build and run on the iOS Simulator, or test from Terminal:

```zsh
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone 16' test
```

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

- Hybrid map centered on South Puget Sound (Area 13 polygon + Thurston launch pins)
- Live WDFW ArcGIS fetch with offline GeoJSON fallback
- Swift Testing unit tests for parsers, scope filters, and model loading
