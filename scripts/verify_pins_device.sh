#!/bin/zsh
# The two pin checks only hardware can answer: the 44pt marker edge tap (the
# Simulator never consults hitRect, see STATUS 2026-10-18) and the pin
# VoiceOver labels. Same shape as verify_weatherkit_device.sh, plus a lock
# check: a locked phone takes the build and then never runs the tests.
#
# The observation is the per-test "passed" lines this prints from the log, not
# this script's exit code — see ~/.claude/skills/ios-build.
set -uo pipefail
cd "$(dirname "$0")/.."

TEST=WAFishMapUITests/MarkerEdgeTapUITests/testAPinIsSelectableFromTheEdgeOfItsTarget
TEST2=WAFishMapUITests/PinVoiceOverProbe/testPinsCarryVoiceOverTextOnScreen
LOG=${TMPDIR:-/tmp}/wafishmap-pins-device.log
JSON=${TMPDIR:-/tmp}/wafishmap-pins-devicectl.json

# A failed devicectl call or parse must not read as "no device attached".
if ! xcrun devicectl list devices --json-output "$JSON" --quiet; then
    echo "devicectl could not list devices (see the error above)." >&2
    exit 1
fi
# A paired iPad that is switched off still appears, with tunnelState
# "unavailable"; counting it would refuse a ready iPhone.
if ! devices=$(/opt/homebrew/bin/python3 -c '
import json, sys
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    c = d["connectionProperties"]
    if c.get("transportType") == "sameMachine" or c.get("tunnelState") == "unavailable":
        continue
    print("\t".join([
        d["hardwareProperties"]["udid"],
        d["deviceProperties"].get("name", "?"),
        c.get("tunnelState", "?"),
        c.get("pairingState", "?"),
        str(d["deviceProperties"].get("developerModeStatus")),
    ]))
' "$JSON"); then
    echo "Could not read devicectl's device list ($JSON)." >&2
    exit 1
fi

count=$(printf '%s' "$devices" | grep -c . || true)
if [ "$count" -gt 1 ]; then
    echo "More than one connected device; refusing to pick one:" >&2
    printf '%s\n' "$devices" >&2
    exit 1
fi
if [ "$count" -eq 1 ]; then
    IFS=$'\t' read -r udid name tunnel pairing devmode <<<"$devices"
    echo "Device: $name ($udid)  tunnel=$tunnel  paired=$pairing  developer-mode=$devmode"
fi
if [ "$count" -eq 0 ] || [ "$tunnel" != "connected" ] || [ "$pairing" != "paired" ] \
   || [ "$devmode" = "None" ]; then
    cat >&2 <<'MSG'

No iPhone is ready. Connect it (cable or same Wi-Fi), unlock it, tap Trust if
asked, and check Settings > Privacy & Security > Developer Mode is on.
MSG
    exit 1
fi

# Anything but an observed passcodeRequired=false refuses: an unreadable lock
# state is not an unlocked phone.
if ! xcrun devicectl device info lockState --device "$udid" --json-output "$JSON" --quiet; then
    echo "Could not read the iPhone's lock state (see the error above)." >&2
    exit 1
fi
locked=$(/opt/homebrew/bin/python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["result"].get("passcodeRequired"))' "$JSON")
if [ "$locked" != "False" ]; then
    echo "The iPhone is locked (passcodeRequired=$locked). Unlock it, keep it awake, and run this again." >&2
    exit 1
fi

echo "==> Running the edge-tap and VoiceOver pin tests on $name (log: $LOG)"
xcodebuild -scheme WAFishMap -destination "platform=iOS,id=$udid" \
    -derivedDataPath DerivedData-device -allowProvisioningUpdates \
    -only-testing:"$TEST" -only-testing:"$TEST2" test >"$LOG" 2>&1
rc=$?
grep -E "Test Case .*(passed|failed|skipped)|error:|\*\* TEST (SUCCEEDED|FAILED) \*\*" "$LOG"
echo "xcodebuild exit $rc"
[ $rc -eq 0 ] || exit $rc
# Exit 0 also covers zero tests run or a skip; only both "passed" lines count.
for t in testAPinIsSelectableFromTheEdgeOfItsTarget testPinsCarryVoiceOverTextOnScreen; do
    if ! grep -q "Test Case .*$t\]' passed" "$LOG"; then
        echo "No 'passed' line for $t in $LOG; not a pass." >&2
        exit 1
    fi
done
echo "Both pin tests passed on $name."
