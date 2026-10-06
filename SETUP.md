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

### Unit-only test plan (for Xcode Cloud)

The scheme's Test action runs both `WAFishMapTests` (unit) and `WAFishMapUITests`.
`WAFishMapUnit.xctestplan` lists only the unit bundle, so a CI Test action can
gate on it without also running the UI probes.

A plan only takes effect once it is added to the scheme. In Xcode: Product ▸ Test
Plan ▸ **Manage Test Plans…**, click **+** below the list, choose **Add existing
Test Plan**, and select `WAFishMapUnit.xctestplan`. The same dialog has a Default
column; leave the existing plan as the default unless you want `⌘U` to skip the
UI tests too.

Confirm the link from Terminal. The plan's name is its file name:

```zsh
xcodebuild -scheme WAFishMap -showTestPlans          # should list WAFishMapUnit
./scripts/run_sim.sh test                            # unchanged: the default plan
```

To run just the unit plan, pass `-testPlan WAFishMapUnit` to the same
`xcodebuild … test` command that `scripts/run_sim.sh` runs.

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
