#!/usr/bin/env python3
"""Write Artifacts/salmon-catch-table/data.js from the board, flight_counts and
no_counts views of ~/database/salmon-rivers/salmon.db. The page is a snapshot:
rerun this, then republish the artifact by passing the URL in artifact.json."""
import datetime
import json
import sqlite3
from pathlib import Path

DB = Path.home() / "database" / "salmon-rivers" / "salmon.db"
OUT = Path(__file__).resolve().parent.parent / "Artifacts" / "salmon-catch-table" / "data.js"

con = sqlite3.connect(DB)
sources, texts, index = [], [], {}


def pick(table, value):
    if value not in index.setdefault(id(table), {}):
        index[id(table)][value] = len(table)
        table.append(value)
    return index[id(table)][value]


rows = [
    [river, species, week, anglers, kept, released, per100, bank, boat, reported, pick(sources, url), pick(texts, text)]
    for river, species, week, anglers, kept, released, per100, bank, boat, reported, url, text in con.execute(
        'SELECT River, Species, Week, Anglers, Kept, Released, "Kept/100", Bank, "Boat rods", Reported, Source, "Report text" FROM board'
    )
]
flights = [
    [week, boats, rods, reported, pick(sources, url), pick(texts, text)]
    for week, boats, rods, reported, url, text in con.execute(
        'SELECT Week, Boats, "Bank rods", Reported, Source, "Report text" FROM flight_counts'
    )
]

weeks = con.execute("SELECT week_start, week_end FROM reports ORDER BY week_start").fetchall()
gaps = []
for (_, end), (start, _) in zip(weeks, weeks[1:]):
    d0 = datetime.date.fromisoformat(end) + datetime.timedelta(days=1)
    d1 = datetime.date.fromisoformat(start) - datetime.timedelta(days=1)
    if (d1 - d0).days >= 6:
        gaps.append(f"{d0} to {d1}")
failures = [
    {"week": w, "river": r, "reason": why, "line": line, "source": src}
    for w, r, why, line, src in con.execute(
        "SELECT f.week, f.river, f.reason, f.line, r.url FROM parse_failures f JOIN reports r USING (pdf)"
    )
]
no_counts = [list(r) for r in con.execute("SELECT Week, Source FROM no_counts")]
data = {
    "built": datetime.date.today().isoformat(),
    "first": weeks[0][0],
    "last": weeks[-1][1],
    "reports": len(weeks),
    "sources": sources,
    "texts": texts,
    "rows": rows,
    "flights": flights,
    "gaps": gaps,
    "failures": failures,
    "noCounts": no_counts,
}
OUT.write_text("window.SALMON = " + json.dumps(data, separators=(",", ":"), ensure_ascii=False) + ";\n")
print(f"wrote {OUT} ({len(rows)} rows, {len(flights)} flights, {len(gaps)} gaps, {len(failures)} failures, {OUT.stat().st_size // 1024} KB)")
