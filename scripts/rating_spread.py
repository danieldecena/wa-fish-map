#!/usr/bin/env python3
"""Print the rating spread the shipped `fisheries.json` actually produces.

The map looked flat and nobody could say by how much. This answers that in
numbers rather than by eye: how many distinct colours the state shows in each
month, how often each rating occurs, and which areas are indistinguishable from
each other all year.

It reimplements `Fishery.swift`'s month logic in Python on purpose. A harness
that imported the Swift would agree with the app by construction and could not
catch a disagreement; this one can, and the Swift side is the source of truth
when they differ.

    python3 scripts/rating_spread.py            # current aggregator
    python3 scripts/rating_spread.py --score    # proposed score + thresholds
"""

import argparse
import collections
import json
import pathlib
import sys

GUIDE = pathlib.Path(__file__).resolve().parent.parent / "WAFishMap/Resources/fisheries.json"
LABEL = {0: "Slow", 1: "Fair", 2: "Good", 3: "Prime"}

# Proposed thresholds, stated as meaning and checked against the histogram —
# never fitted to it. See docs/data-accuracy-plan.md.
PRIME, GOOD, FAIR = 3.75, 2.75, 1.5


def circular_month_distance(a: int, b: int) -> int:
    raw = abs(a - b) % 12
    return min(raw, 12 - raw)


def risk_months(species: dict, table: list) -> set:
    if (species.get("seasonRisk") or "").lower() == "none":
        return set()
    months = set()
    for row in table:
        if row["match"].lower() in species["species"].lower():
            months |= set(row["months"])
    return months


def rate(species: dict, month: int, table: list, year: int) -> int:
    """One species' 0-3 rating in `month`, matching `SpeciesSeason.rating(inMonth:)`."""
    parity = (species.get("years") or "").lower()
    if (parity == "odd" and year % 2 == 0) or (parity == "even" and year % 2 != 0):
        return 0
    if month in species["bestMonths"]:
        base = 3
    elif month in species.get("goodMonths", []):
        base = 2
    else:
        seasons = species["bestMonths"] + species.get("goodMonths", [])
        base = 1 if any(circular_month_distance(m, month) == 1 for m in seasons) else 0
    return min(base, 1) if month in risk_months(species, table) else base


def top_three(area: dict, month: int, table: list, year: int) -> list:
    rated = sorted((rate(s, month, table, year) for s in area["species"]), reverse=True)
    return (rated + [0, 0, 0])[:3]


def breadth_rating(area: dict, month: int, table: list, year: int) -> int:
    """Today's aggregator: round(mean(top 3))."""
    top = [r for r in sorted((rate(s, month, table, year) for s in area["species"]), reverse=True)][:3]
    if not top:
        return 0
    # Python banker's-rounds .5 to even; Swift's `.rounded()` rounds half away
    # from zero. Match Swift, or the two disagree on exactly the tie cases.
    mean = sum(top) / len(top)
    return int(mean + 0.5)


def score(area: dict, month: int, table: list, year: int) -> float:
    """Proposed: depth-led, breadth as tiebreak. Range 0 - 5.25."""
    best, second, third = top_three(area, month, table, year)
    return best + 0.5 * second + 0.25 * third


def bucket(value: float) -> int:
    if value >= PRIME:
        return 3
    if value >= GOOD:
        return 2
    if value >= FAIR:
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--score", action="store_true", help="use the proposed score + thresholds")
    parser.add_argument("--year", type=int, default=2026, help="plan year (sets odd/even-run parity)")
    args = parser.parse_args()

    guide = json.loads(GUIDE.read_text())
    table = guide.get("seasonRisk", [])
    areas = guide["areas"]

    def colour(area, month):
        if args.score:
            return bucket(score(area, month, table, args.year))
        return breadth_rating(area, month, table, args.year)

    names = [a["areaName"] for a in areas]
    print(f"{'aggregator:':<12} {'score + thresholds' if args.score else 'round(mean(top 3))'}   year {args.year}")
    print()
    print("month " + " ".join(f"{n:>5}" for n in names) + "   distinct")
    cells = []
    for month in range(1, 13):
        values = [colour(a, month) for a in areas]
        cells += values
        print(f"{month:>5} " + " ".join(f"{LABEL[v]:>5}" for v in values) + f"   {len(set(values))}")

    print()
    counts = collections.Counter(cells)
    total = len(cells)
    print(f"over {total} area-months:")
    for value in range(4):
        n = counts.get(value, 0)
        print(f"  {LABEL[value]:<6} {n:>4}  {n / total:>5.1%}")

    print()
    print("areas that are indistinguishable all year (same 12-month string):")
    strings = collections.defaultdict(list)
    for area in areas:
        key = "".join(str(colour(area, m)) for m in range(1, 13))
        strings[key].append(area["areaName"])
    twins = {k: v for k, v in strings.items() if len(v) > 1}
    if not twins:
        print("  none")
    for key, group in sorted(twins.items()):
        print(f"  {key}  {', '.join(group)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
