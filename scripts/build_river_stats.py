#!/usr/bin/env python3
"""Generate WAFishMap/Resources/river_stats.json — each river's own flow history.

A river's discharge in cfs means nothing across rivers: the Columbia dwarfs
everything, so an absolute scale would paint the whole state the same. What an
angler actually reads is "is this river high or low *for the time of year*", so
the app needs each river's own day-of-year distribution to locate today's
reading in. That table is what this builds.

It is static — 85 years of record does not move because a day passed — so it is
bundled and regenerated yearly, while the live reading is one call at runtime.
That split is the whole design: history offline, observation online.

Sources, both free and keyless:
  * nwis/iv   enumerates active WA gauges and their names (used here only to
              decide which gauges matter; the app calls it for live values)
  * nwis/stat daily statistics, giving p10/p25/p50/p75/p90 per month and day

A gauge is joined to a river by parsing its site name ("SKAGIT RIVER NEAR
CONCRETE, WA" -> "Skagit River") and matching against rivers.json. Where a
river has several gauges, the one with the longest period of record wins —
a long record makes the percentiles mean more, and a short one can put today
in the 95th percentile purely because it has not seen a big year yet.

    ./scripts/build_river_stats.py [--out PATH]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

IV = "https://waterservices.usgs.gov/nwis/iv/"
STAT = "https://waterservices.usgs.gov/nwis/stat/"

DISCHARGE = "00060"
WATER_TEMP = "00010"

# The stat service caps a comma-separated site list at 10 — 12 returns a bare
# HTML 400 with no explanation. Batching still cuts this to ~18 requests
# instead of one per gauge.
BATCH = 10

# Percentiles kept, in this order. Five is enough to place a reading and to say
# something in words; the app never interpolates between them.
PERCENTILES = ["p10_va", "p25_va", "p50_va", "p75_va", "p90_va"]

REPO = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO / "WAFishMap/Resources/river_stats.json"
RIVERS = REPO / "WAFishMap/Resources/rivers.json"

# Anchors, same idea as build_rivers.py: these are the rivers whose flow anyone
# would actually check, and every one of them has a long-record gauge. If the
# join silently breaks, the file still looks plausible without them.
EXPECTED = {
    "Skagit River",
    "Snoqualmie River",
    "Yakima River",
    "Cowlitz River",
    "Wenatchee River",
    "Chehalis River",
}


def get(url: str, params: dict) -> str:
    full = f"{url}?{urllib.parse.urlencode(params)}"
    try:
        with urllib.request.urlopen(full, timeout=180) as response:
            return response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        # Keep the body. USGS answers a too-large site list with a bare 400 and
        # an HTML page, and the status alone cannot tell that from a bad site id.
        body = error.read().decode("utf-8", errors="replace")[:500]
        raise SystemExit(f"{url} returned HTTP {error.code}\n{body}")


def river_of(site_name: str) -> str | None:
    """ "SKAGIT RIVER NEAR CONCRETE, WA" -> "Skagit River"."""
    match = re.match(r"^(.*?\bRIVER)\b", site_name.upper())
    if not match:
        return None
    name = re.sub(
        r"^(EF|WF|NF|SF|MF|EAST FORK|WEST FORK|NORTH FORK|SOUTH FORK|MIDDLE FORK)\s+",
        "",
        match.group(1),
    )
    return name.title()


def candidate_gauges(river_names: set[str]) -> dict[str, dict]:
    """WA gauges reporting discharge whose name resolves to a drawn river."""
    payload = json.loads(
        get(
            IV,
            {
                "format": "json",
                "stateCd": "wa",
                "parameterCd": f"{DISCHARGE},{WATER_TEMP}",
                "siteStatus": "active",
            },
        )
    )
    gauges: dict[str, dict] = {}
    for series in payload["value"]["timeSeries"]:
        info = series["sourceInfo"]
        site = info["siteCode"][0]["value"]
        entry = gauges.setdefault(site, {"name": info["siteName"], "params": set()})
        entry["params"].add(series["variable"]["variableCode"][0]["value"])

    keep: dict[str, dict] = {}
    for site, entry in gauges.items():
        if DISCHARGE not in entry["params"]:
            continue
        river = river_of(entry["name"])
        if river in river_names:
            keep[site] = {
                "name": entry["name"],
                "river": river,
                "hasTemp": WATER_TEMP in entry["params"],
            }
    return keep


def fetch_stats(sites: list[str]) -> dict[str, dict]:
    """site -> {"months": {month: {day: [p10..p90]}}, "beginYear", "endYear"}."""
    out: dict[str, dict] = {}
    for start in range(0, len(sites), BATCH):
        batch = sites[start : start + BATCH]
        text = get(
            STAT,
            {
                "format": "rdb",
                "sites": ",".join(batch),
                "statReportType": "daily",
                "statTypeCd": "all",
                "parameterCd": DISCHARGE,
            },
        )
        rows = [
            line.split("\t")
            for line in text.splitlines()
            if line and not line.startswith("#")
        ]
        if not rows:
            raise SystemExit(f"stat service returned no rows for {batch}")
        header = rows[0]
        index = {
            name: header.index(name)
            for name in [
                "site_no",
                "month_nu",
                "day_nu",
                "begin_yr",
                "end_yr",
                *PERCENTILES,
            ]
        }
        for row in rows[2:]:  # row 1 is the RDB type line
            if len(row) < len(header):
                continue
            site = row[index["site_no"]]
            values = [row[index[p]] for p in PERCENTILES]
            if any(v == "" for v in values):
                continue
            entry = out.setdefault(site, {"months": {}, "beginYear": 0, "endYear": 0})
            month = str(int(row[index["month_nu"]]))
            day = int(row[index["day_nu"]])
            entry["months"].setdefault(month, {})[day] = [
                round(float(v), 1) for v in values
            ]
            entry["beginYear"] = int(row[index["begin_yr"]])
            entry["endYear"] = int(row[index["end_yr"]])
        print(f"  stats for {len(batch)} gauges", file=sys.stderr)
    return out


def build(gauges: dict[str, dict], stats: dict[str, dict]) -> dict:
    """One gauge per river: the longest record wins."""
    best: dict[str, tuple[int, str]] = {}
    for site, meta in gauges.items():
        stat = stats.get(site)
        if not stat or not stat["months"]:
            continue
        record = stat["endYear"] - stat["beginYear"]
        current = best.get(meta["river"])
        if current is None or record > current[0]:
            best[meta["river"]] = (record, site)

    rivers = {}
    for river in sorted(best):
        _, site = best[river]
        stat = stats[site]
        months = {
            month: [stat["months"][month][day] for day in sorted(stat["months"][month])]
            for month in sorted(stat["months"], key=int)
        }
        rivers[river] = {
            "gauge": site,
            "gaugeName": gauges[site]["name"],
            "hasTemp": gauges[site]["hasTemp"],
            "beginYear": stat["beginYear"],
            "endYear": stat["endYear"],
            "percentiles": [p.replace("_va", "") for p in PERCENTILES],
            "months": months,
        }
    return {"rivers": rivers}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    river_names = {
        feature["properties"]["name"]
        for feature in json.loads(RIVERS.read_text())["features"]
    }
    print(f"{len(river_names)} rivers drawn; finding their gauges…", file=sys.stderr)

    try:
        gauges = candidate_gauges(river_names)
        print(
            f"{len(gauges)} gauges on {len({g['river'] for g in gauges.values()})} rivers",
            file=sys.stderr,
        )
        stats = fetch_stats(sorted(gauges))
    except (urllib.error.URLError, TimeoutError) as error:
        raise SystemExit(f"USGS unreachable: {error}")

    payload = build(gauges, stats)
    missing = sorted(EXPECTED - set(payload["rivers"]))
    if missing:
        raise SystemExit(
            "anchor rivers have no flow history, so the join is wrong rather "
            f"than the data: {', '.join(missing)}"
        )

    args.out.write_text(
        json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n"
    )
    temps = sum(1 for r in payload["rivers"].values() if r["hasTemp"])
    print(
        f"{len(payload['rivers'])} rivers with flow history "
        f"({temps} also report water temp), "
        f"{args.out.stat().st_size / 1024:.0f} KB -> {args.out}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
