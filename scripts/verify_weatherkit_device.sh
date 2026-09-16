#!/bin/zsh
# One command for the one thing the Simulator cannot do.
#
# WeatherKit mints its JWT from the provisioning profile. A Simulator build is
# ad-hoc signed and has none, so the fetch there fails with
# "Failed to generate jwt token ... Code=2" and the view honestly reports
# "unavailable". Only hardware can answer whether the live path works.
#
# The observation is the XCUITest assertion, not this script's exit code and not
# xcodebuild's "TEST SUCCEEDED" — see ~/.claude/skills/ios-build.
set -euo pipefail
cd "$(dirname "$0")/.."

TEST=WAFishMapUITests/VerifyBadgeUITests/testWindReadsARealValueOnDevice

# Refuse ambiguity rather than guessing. A previous run built for an iPad that
# had silently replaced the iPhone in the device list.
devices=$(xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null | python3 -c '
import json, sys
for d in json.load(sys.stdin)["result"]["devices"]:
    c = d["connectionProperties"]
    if c.get("transportType") == "sameMachine":
        continue                      # a Simulator, not the thing we are here for
    print("\t".join([
        d["hardwareProperties"]["udid"],
        d["deviceProperties"].get("name", "?"),
        c.get("tunnelState", "?"),
        c.get("pairingState", "?"),
        str(d["deviceProperties"].get("developerModeStatus")),
    ]))
')

count=$(printf '%s' "$devices" | grep -c . || true)
if [ "$count" -eq 0 ]; then
    echo "No physical iOS device is attached." >&2
    count=0
elif [ "$count" -gt 1 ]; then
    echo "More than one physical device is attached; refusing to pick one:" >&2
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

The device is not ready to take a build. On the iPhone:
  1. Plug in a DATA cable (a charge-only cable never appears at all).
  2. Unlock it and keep it awake — a locked device drops out of devicectl.
  3. Tap Trust on "Trust This Computer?" and enter the passcode.
  4. Settings > Privacy & Security > Developer Mode -> on, then restart.
Then run this script again.
MSG
    exit 1
fi

echo "==> Running $TEST on the device"
xcodebuild -scheme WAFishMap -destination "platform=iOS,id=$udid" \
    -allowProvisioningUpdates -only-testing:"$TEST" test

# "App installed" is not an observation either. Ask the device what it holds.
echo "==> Confirming the app is on the device"
xcrun devicectl device info apps --device "$udid" | grep -i WAFishMap
