#!/usr/bin/env python3
"""Write Artifacts/salmon-catch-table/data.js: a mirror of every sheet in
~/database/salmon-rivers/salmon.db (the views VisiData opens), same columns and
same rows, stamped with the database's own build time. Refuses to write if a
sheet's exported row count differs from a count taken straight from the tables
behind it, so a join that drops rows is caught.

The page is a snapshot: rerun this, then republish the artifact by passing the
URL in artifact.json."""
import datetime
import json
import sqlite3
from pathlib import Path

DB = Path.home() / "database" / "salmon-rivers" / "salmon.db"
OUT = Path(__file__).resolve().parent.parent / "Artifacts" / "salmon-catch-table" / "data.js"
SHEETS = [("board", "Catch by river"), ("flight_counts", "Flight counts"), ("weeks", "Weeks"), ("not_parsed", "Not parsed")]
SHARED = {"Source": [], "Report text": []}  # long strings stored once, rows hold an index
# What each sheet's row count must equal, counted from the tables and not from the view.
INDEPENDENT = {
    "board": "SELECT count(*) FROM entries e LEFT JOIN catch c ON c.entry_id = e.id WHERE e.status IN ('reported', 'no catch', 'not parsed')",
    "flight_counts": "SELECT count(*) FROM flights",
    "weeks": "SELECT count(*) FROM reports",
    "not_parsed": "SELECT count(*) FROM parse_failures",
}

def export(db=DB, out=OUT):
    for pool in SHARED.values():
        pool.clear()
    con = sqlite3.connect(db)
    sheets, counts = [], {}
    for view, label in SHEETS:
        cur = con.execute(f"SELECT * FROM {view}")
        names = [d[0] for d in cur.description]
        raw = cur.fetchall()
        cols = []
        for i, name in enumerate(names):
            vals = [r[i] for r in raw if r[i] is not None]
            cols.append({"name": name, "n": bool(vals) and all(isinstance(v, (int, float)) for v in vals), "shared": name in SHARED})
        rows = []
        for r in raw:
            row = []
            for i, v in enumerate(r):
                if cols[i]["shared"] and v is not None:
                    pool = SHARED[cols[i]["name"]]
                    if v not in pool:
                        pool.append(v)
                    v = pool.index(v)
                row.append(v)
            rows.append(row)
        counts[view] = con.execute(INDEPENDENT[view]).fetchone()[0]
        if len(rows) != counts[view]:
            raise SystemExit(f"{view}: exported {len(rows)} rows, the tables behind it have {counts[view]}")
        sheets.append({"view": view, "label": label, "cols": cols, "rows": rows})

    built = con.execute("SELECT value FROM meta WHERE key = 'built_at'").fetchone()[0]
    weeks = con.execute("SELECT week_start, week_end FROM reports ORDER BY week_start").fetchall()
    gaps = []
    for (_, end), (start, _) in zip(weeks, weeks[1:]):
        d0 = datetime.date.fromisoformat(end) + datetime.timedelta(days=1)
        d1 = datetime.date.fromisoformat(start) - datetime.timedelta(days=1)
        if (d1 - d0).days >= 6:
            gaps.append(f"{d0} to {d1}")
    data = {
        "built": built,
        "first": weeks[0][0],
        "last": weeks[-1][1],
        "counts": counts,
        "sources": SHARED["Source"],
        "texts": SHARED["Report text"],
        "sheets": sheets,
        "gaps": gaps,
    }
    out.write_text("window.SALMON = " + json.dumps(data, separators=(",", ":"), ensure_ascii=False) + ";\n")
    print(f"wrote {out.name} ({out.stat().st_size // 1024} KB), db built {built}: " + ", ".join(f"{k} {v}" for k, v in counts.items()))


if __name__ == "__main__":
    export()
