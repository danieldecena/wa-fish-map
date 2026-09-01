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
# Any installed iPhone simulator works — list yours with:
#   xcrun simctl list devices available | grep iPhone
xcodebuild -scheme WAFishMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

CI does not name a device at all — it resolves one from `xcrun simctl` so the
job cannot break when a runner image drops a model. See
`.github/workflows/ci.yml`.

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
