#!/usr/bin/env python3
"""Check every gauged river's flow colour against USGS, not just on screen.

For each river in river_stats.json this does two things:

1. Re-fetches the gauge's daily statistics from nwis/stat and compares every
   bundled p10..p90 row against the source. A mismatch fails the run: the
   table is supposed to be a faithful copy, so drift means regenerate it with
   build_river_stats.py.
2. Reads the gauge's live discharge from nwis/iv (the same statewide call the
   app makes) and prints the band that reading draws, with today's percentile
   row beside it, so each colour can be traced to its numbers.

    ./scripts/verify_river_stats.py [--date YYYY-MM-DD]

Exit 1 on any table mismatch. A river with no live reading is listed as
"no reading", never given a band.
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
import urllib.error
from zoneinfo import ZoneInfo

from build_river_stats import DEFAULT_OUT, DISCHARGE, IV, fetch_stats, get


def band(discharge: float, row: list[float]) -> str:
    """Mirrors RiverFlowStats.rating(discharge:month:day:)."""
    p10, p25, _, p75, p90 = row
    if discharge < p10 or discharge >= p90:
        return "Slow"
    if discharge < p25 or discharge >= p75:
        return "Fair"
    return "Good"


def row_for(months: dict, month: int, day: int) -> list[float] | None:
    """Mirrors RiverFlowStats.percentiles(month:day:), Feb 29 fallback included."""
    days = months.get(str(month)) or []
    if day < 1 or day > len(days) + 1:
        return None
    return days[min(day, len(days)) - 1]


def live_discharge() -> dict[str, float]:
    text = get(
        IV,
        {
            "format": "json",
            "stateCd": "wa",
            "parameterCd": DISCHARGE,
            "siteStatus": "active",
        },
    )
    readings: dict[str, float] = {}
    for series in json.loads(text)["value"]["timeSeries"]:
        site = series["sourceInfo"]["siteCode"][0]["value"]
        samples = [v for block in series["values"] for v in block["value"]]
        if not samples:
            continue
        value = float(samples[-1]["value"])
        if value > -1000:  # USGS sentinel for "no value", same guard as the app
            readings[site] = value
    return readings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", type=datetime.date.fromisoformat)
    args = parser.parse_args()
    today = args.date or datetime.datetime.now(ZoneInfo("America/Los_Angeles")).date()

    bundled = json.loads(DEFAULT_OUT.read_text())["rivers"]
    gauges = {river["gauge"]: name for name, river in bundled.items()}
    try:
        source = fetch_stats(sorted(gauges))
        live = live_discharge()
    except (urllib.error.URLError, TimeoutError) as error:
        raise SystemExit(f"USGS unreachable: {error}")

    mismatches = 0
    for name in sorted(bundled):
        river = bundled[name]
        stat = source.get(river["gauge"])
        if stat is None:
            print(f"[x] {name}: gauge {river['gauge']} returned no statistics")
            mismatches += 1
            continue
        wrong = [
            f"{month}/{day + 1}"
            for month, days in river["months"].items()
            for day, row in enumerate(days)
            if stat["months"].get(month, {}).get(day + 1) != row
        ]
        if wrong:
            print(f"[x] {name}: {len(wrong)} rows differ from USGS, first {wrong[:3]}")
            mismatches += 1

        row = row_for(river["months"], today.month, today.day)
        reading = live.get(river["gauge"])
        if row is None or reading is None:
            print(f"    {name}: no reading")
        else:
            print(f"    {name}: {reading:g} cfs, p10-p90 {row} -> {band(reading, row)}")

    print(
        f"{len(bundled)} rivers, {mismatches} with table drift, date {today}",
        file=sys.stderr,
    )
    return 1 if mismatches else 0


if __name__ == "__main__":
    sys.exit(main())
