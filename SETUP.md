# WAFishMap — Mac setup

The repo ships a complete `WAFishMap.xcodeproj` (Xcode 16 file-system synchronized
groups). Open and build — no manual project creation needed.

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
xcodebuild -scheme WAFishMap -destination 'platform=iOS Simulator,name=iPhone 16' test
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
