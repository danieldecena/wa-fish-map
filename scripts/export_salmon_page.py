#!/usr/bin/env python3
"""Write Artifacts/salmon-catch-table/data.js from the board view of
~/database/salmon-rivers/salmon.db. The page is a snapshot: rerun this, then
republish the artifact by passing the URL in artifact.json."""
import datetime
import json
import sqlite3
from pathlib import Path

DB = Path.home() / "database" / "salmon-rivers" / "salmon.db"
OUT = Path(__file__).resolve().parent.parent / "Artifacts" / "salmon-catch-table" / "data.js"

con = sqlite3.connect(DB)
sources = []
rows = []
for river, species, week, anglers, kept, released, url in con.execute("SELECT * FROM board"):
    if url not in sources:
        sources.append(url)
    rows.append([river, species, week, anglers, kept, released, sources.index(url)])

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
        "SELECT f.week, f.river, f.reason, f.line, r.url FROM parse_failures f JOIN reports r USING (pdf)")
]
data = {
    "built": datetime.date.today().isoformat(),
    "first": weeks[0][0],
    "last": weeks[-1][1],
    "reports": len(weeks),
    "sources": sources,
    "rows": rows,
    "gaps": gaps,
    "failures": failures,
}
OUT.write_text("window.SALMON = " + json.dumps(data, separators=(",", ":")) + ";\n")
print(f"wrote {OUT} ({len(rows)} rows, {len(sources)} sources, {len(gaps)} gaps, {len(failures)} failures)")
