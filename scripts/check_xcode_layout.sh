#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Repo: $ROOT"
echo

fail=0

if [[ -f WAFishMap.xcodeproj/project.pbxproj ]]; then
  echo "[ok] WAFishMap.xcodeproj/project.pbxproj"
else
  echo "[x]  missing WAFishMap.xcodeproj/project.pbxproj"
  fail=1
fi

for f in WAFishMap/ContentView.swift WAFishMap/WAFishMapApp.swift WAFishMap/FishingMapView.swift; do
  if [[ -f "$f" ]]; then
    echo "[ok] $f"
  else
    echo "[x]  missing $f"
    fail=1
  fi
done

swift_count="$(find WAFishMap -name '*.swift' | wc -l | tr -d ' ')"
echo
echo "Swift files under WAFishMap/: $swift_count (expect 10)"
if [[ "$swift_count" -lt 10 ]]; then
  echo "[x]  too few Swift sources — git checkout or re-clone"
  fail=1
fi

if grep -q PBXFileSystemSynchronizedRootGroup WAFishMap.xcodeproj/project.pbxproj 2>/dev/null; then
  echo "[ok] synchronized groups enabled"
else
  echo "[x]  project missing synchronized groups"
  fail=1
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "Layout OK. If Xcode navigator is empty:"
  echo "  1. Quit Xcode"
  echo "  2. rm -rf ~/Library/Developer/Xcode/DerivedData/WAFishMap-*"
  echo "  3. open WAFishMap.xcodeproj"
  echo "  4. Expand the WAFishMap folder in the navigator"
else
  echo "Fix layout before opening Xcode. See SETUP.md troubleshooting."
  exit 1
fi
