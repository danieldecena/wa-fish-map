# WAFishMap

Native MapKit overlay of WDFW Marine Area 13 (South Puget Sound) plus
Thurston County water-access launches.

Widen the slice by editing `WAFishMap/Models/MapScope.swift` only.

Overlays are geography, not the rulebook. Check Fish Washington before you fish.

## Mac setup (required once)

This repo ships Swift sources only. Xcode must create the project on your Mac:

1. Clone to `~/developer/wa-fish-map`
2. Follow [SETUP.md](SETUP.md) to attach `WAFishMap.xcodeproj`
3. Build and run on the iOS Simulator

```zsh
cd ~/developer/wa-fish-map
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone 16' test
```
