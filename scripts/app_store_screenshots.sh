#!/bin/zsh
# Capture App Store–oriented simulator screenshots after a build is installed.
# Requires a booted iPhone simulator and WAFishMap.app already built for it.
#
# Usage:
#   scripts/app_store_screenshots.sh [-d udid|name] [-o outdir]
#
# Produces PNGs under docs/app-store/screenshots/ (or -o). Does not upload to ASC.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="com.danieldecena.WAFishMap"
outdir="$ROOT/docs/app-store/screenshots"
device=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device|-o|--outdir)
      [[ $# -ge 2 ]] || { echo "[x] $1 requires a value" >&2; exit 2; } ;;
  esac
  case "$1" in
    -d|--device) device="$2"; shift 2 ;;
    -o|--outdir) outdir="$2"; shift 2 ;;
    -h|--help)
      echo "usage: $0 [-d udid|name] [-o outdir]"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

pick_booted() {
  xcrun simctl list devices booted --json | python3 -c '
import json, sys
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if ".iOS-" not in runtime:
        continue
    for d in devices:
        print(d["udid"]); sys.exit(0)
'
}

if [[ -n "$device" ]]; then
  udid=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
want = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["udid"] == want or d["name"] == want:
            print(d["udid"]); sys.exit(0)
sys.exit("device not found: " + want)
' "$device")
else
  udid="$(pick_booted)"
  [[ -n "$udid" ]] || { echo "[x] no booted iPhone simulator" >&2; exit 1; }
fi

mkdir -p "$outdir"
xcrun simctl bootstatus "$udid" -b >/dev/null
if ! xcrun simctl get_app_container "$udid" "$BUNDLE_ID" >/dev/null 2>&1; then
  echo "[x] $BUNDLE_ID is not installed on $udid — build and install first (scripts/run_sim.sh)" >&2
  exit 1
fi
xcrun simctl privacy "$udid" grant location "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl location "$udid" set 47.29,-122.52 2>/dev/null || true
trap 'xcrun simctl status_bar "$udid" clear; xcrun simctl ui "$udid" appearance light' EXIT
xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

# The regional map loads 477 live WDFW sites; 4 s caught it mid-load with the
# footer spinner showing, so give the first frame time to settle.
shot() {
  local name="$1" wait="${2:-4}"
  sleep "$wait"
  xcrun simctl io "$udid" screenshot "$outdir/$name.png"
  echo "[ok] $outdir/$name.png"
}

# 1) Live regional map
xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
shot "01-map-regional" 15

# 2) Site detail via UI-test seam (Boston Harbor + guidance footer)
xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$udid" "$BUNDLE_ID" -- -uiTesting -planMonth 8 >/dev/null
shot "02-site-detail-guidance"

# 3-4) The other two sheets. Every sheet has to carry the disclaimer and the
# WDFW link, so every sheet gets a frame — tapping pins on a clustered map is
# exactly the moving target the seam exists to avoid.
xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$udid" "$BUNDLE_ID" -- -uiTesting -planMonth 8 -uiTestingDetail pier >/dev/null
shot "03-pier-detail"

xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$udid" "$BUNDLE_ID" -- -uiTesting -planMonth 8 -uiTestingDetail river >/dev/null
shot "04-river-detail"

# 5-6) Dark appearance. The rating ramp is four hardcoded RGBs that do not
# follow the appearance, so the dark frames are the observation for whether
# they still hold up against a dark basemap and a dark sheet.
xcrun simctl ui "$udid" appearance dark
xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
shot "05-map-regional-dark" 15

xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$udid" "$BUNDLE_ID" -- -uiTesting -planMonth 8 >/dev/null
shot "06-site-detail-dark"
xcrun simctl ui "$udid" appearance light

# 7-8) The ramp gate. Not App Store frames -- these exist to answer "do the
# ratings separate at arm's length", so they go somewhere they cannot be
# uploaded to ASC by accident.
#
# Two things make them a gate rather than a screenshot. The camera is pinned,
# because the live frames above reframe themselves from the location fix and
# two runs produced different regions and zooms, so nothing could be compared.
# And the month is November, chosen because it is the one month that puts all
# four ratings in adjacent Puget Sound areas: Prime in 10/11/12, Good in 8-2
# and 13, Fair in 8-1 and 9, Slow in 5/6/7. The live frames are whatever the
# current month happens to be, which in September is 85% Good.
# The span is load-bearing. MapDetailLevel hands pins over to the density
# overlay past 400 km of camera distance, and a 2.0-degree span crosses it --
# the first attempt at this frame came back as a violet heat map with no pins
# on it at all. 1.3 is wide enough to hold MA 6, 9, 8-2, 11 and the inland
# lakes together and still short of that handover.
gatedir="$ROOT/docs/design/ramp-check"
mkdir -p "$gatedir"
REGION="47.95,-123.00,1.3"

xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$udid" "$BUNDLE_ID" -- -planMonth 11 -uiTestingRegion "$REGION" >/dev/null
sleep 15
xcrun simctl io "$udid" screenshot "$gatedir/ramp-light.png"
echo "[ok] $gatedir/ramp-light.png"

xcrun simctl ui "$udid" appearance dark
xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$udid" "$BUNDLE_ID" -- -planMonth 11 -uiTestingRegion "$REGION" >/dev/null
sleep 15
xcrun simctl io "$udid" screenshot "$gatedir/ramp-dark.png"
echo "[ok] $gatedir/ramp-dark.png"
xcrun simctl ui "$udid" appearance light

echo
echo "Open $outdir and crop to ASC device sizes in Preview or Transporter."
echo "Toggle Heat / species in the Simulator for extra frames if you want them."
