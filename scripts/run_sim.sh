#!/bin/zsh
# Build WAFishMap, install it on a simulator, launch it, and put the camera
# somewhere the seasonal rating is actually visible.
#
# Resolves the device instead of naming one, for the reason CI does: a
# hardcoded model is drift waiting to happen. 'iPhone 16 Pro' does not exist
# on an Xcode 26 install, which ships the iPhone 17 family.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="WAFishMap"
BUNDLE_ID="com.danieldecena.WAFishMap"
DERIVED="${WAFISHMAP_DERIVED_DATA:-/tmp/wafishmap-dd}"

# Tacoma, inside Marine Area 11 and inside the Washington bbox — so the camera
# takes the regional-span ease instead of sitting on the statewide auto-fit.
# A fix outside Washington deliberately keeps the statewide framing.
location="47.29,-122.52"
device=""
shot=""

usage() {
  cat <<'EOF'
usage: scripts/run_sim.sh [options]

  -d, --device <udid|name>  simulator to use (default: booted, else newest iPhone)
  -l, --location <lat,lon>  simulated GPS fix (default: 47.29,-122.52, Area 11)
      --no-location         skip the fix; app stays on statewide auto-fit
  -s, --shot <path>         screenshot after launch
  -h, --help                this

env: WAFISHMAP_DERIVED_DATA overrides the build directory.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)   device="$2"; shift 2 ;;
    -l|--location) location="$2"; shift 2 ;;
    --no-location) location=""; shift ;;
    -s|--shot)     shot="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "[x]  unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# --- resolve a device -------------------------------------------------------

pick_newest_iphone() {
  xcrun simctl list devices available --json | python3 -c '
import json, re, sys
candidates = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.search(r"iOS-([\d-]+)$", runtime)
    if not match:
        continue
    version = tuple(int(part) for part in match.group(1).split("-"))
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            candidates.append((version, device["name"], device["udid"]))
if not candidates:
    sys.exit("no available iPhone simulator — install a runtime in Xcode > Settings > Components")
version, name, udid = max(candidates)
print("%s on iOS %s" % (name, ".".join(map(str, version))), file=sys.stderr)
print(udid)
'
}

booted_udid() {
  # Only iOS devices: a booted watch or iPad sim from another session is not a
  # valid build destination for this scheme.
  xcrun simctl list devices booted --json | python3 -c '
import json, sys
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if ".iOS-" not in runtime:
        continue
    for device in devices:
        print(device["udid"])
        sys.exit()
'
}

# xcodebuild -destination "id=..." takes only a UDID, so a name passed to -d
# has to be resolved here; the newest iOS runtime wins when several carry it.
resolve_device() {
  xcrun simctl list devices available --json | python3 -c '
import json, re, sys
want = sys.argv[1]
candidates = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.search(r"iOS-([\d-]+)$", runtime)
    version = tuple(int(part) for part in match.group(1).split("-")) if match else ()
    for device in devices:
        if device["udid"] == want:
            print(want)
            sys.exit()
        if match and device["name"] == want:
            candidates.append((version, device["udid"]))
if not candidates:
    sys.exit("no available simulator named or identified by %r" % want)
print(max(candidates)[1])
' "$1"
}

if [[ -n "$device" ]]; then
  udid="$(resolve_device "$device")"
elif udid="$(booted_udid)" && [[ -n "$udid" ]]; then
  echo "[ok] reusing booted simulator"
else
  udid="$(pick_newest_iphone)"
fi

# 'boot' errors when the device is already booted; that is the happy path here.
xcrun simctl boot "$udid" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$udid" -b >/dev/null
echo "[ok] simulator $udid booted"

# --- build ------------------------------------------------------------------

echo "[..] building $SCHEME (Xcode 26+ required — GlassCard needs the iOS 26 SDK)"
xcodebuild -scheme "$SCHEME" \
  -destination "id=$udid" \
  -derivedDataPath "$DERIVED" \
  -skipPackagePluginValidation \
  build

app="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
if [[ ! -d "$app" ]]; then
  echo "[x]  build succeeded but no app at $app" >&2
  exit 1
fi

# --- install, locate, launch ------------------------------------------------

# The build can run for minutes, long enough for another session to shut the
# device down (observed 2026-09-16: install failed with SimError 405 Shutdown).
xcrun simctl bootstatus "$udid" -b >/dev/null

xcrun simctl install "$udid" "$app"
echo "[ok] installed $BUNDLE_ID"

if [[ -n "$location" ]]; then
  # The fix only reaches the app once it holds location permission, and a
  # fresh simulator has not granted it — without this the camera stays on the
  # statewide auto-fit no matter what fix is set (observed 2026-09-16).
  xcrun simctl privacy "$udid" grant location "$BUNDLE_ID"
  # simctl location landed in Xcode 14; tolerate its absence rather than
  # failing a build that is otherwise fine.
  if xcrun simctl location "$udid" set "$location" 2>/dev/null; then
    echo "[ok] location set to $location"
  else
    echo "[!]  could not set location — camera will stay on statewide auto-fit"
  fi
fi

xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
echo "[ok] launched"

if [[ -n "$shot" ]]; then
  # The map needs a beat to fetch WDFW areas and launches before it is worth
  # photographing.
  sleep 6
  xcrun simctl io "$udid" screenshot "$shot"
  echo "[ok] screenshot $shot"
fi

cat <<'EOF'

Sanity check what you see:
  - markers run blue -> amber -> orange -> red by month (guidance, not regulation)
  - inland/lake launches are gray: they match no marine-area polygon, by design
  - every screen showing guidance carries the disclaimer and the WDFW link
EOF
