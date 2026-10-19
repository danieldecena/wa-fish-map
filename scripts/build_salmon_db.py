#!/usr/bin/env python3
"""Build ~/database/salmon-rivers/salmon.db from WDFW's weekly Southwest
Washington Columbia River and Tributary Fishery Report PDFs.

    build_salmon_db.py            parse the PDFs already downloaded, rebuild the db
    build_salmon_db.py --fetch    first download any 2025/2026 PDFs not yet on disk

The db is a table for people to read (view `board`, opened by ~/bin/data-table
salmon). These are creel counts, not ratings: nothing here feeds the rivers
page. A value the report does not state is NULL, never 0; an entry that cannot
be parsed is kept as a visible row, not dropped.
"""

import argparse
import datetime
import re
import sqlite3
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

HOST = "https://wdfw.wa.gov"
INDEX = HOST + "/fishing/reports/creel/southwest"
ROOT = Path.home() / "database" / "salmon-rivers"
PDFS = ROOT / "pdf"
DB = ROOT / "salmon.db"
YEARS = tuple(str(y) for y in range(2019, 2027))

MONTHS = {
    m: i
    for i, m in enumerate(
        [
            "jan",
            "feb",
            "mar",
            "apr",
            "may",
            "jun",
            "jul",
            "aug",
            "sep",
            "oct",
            "nov",
            "dec",
        ],
        1,
    )
}
UNITS = {
    w: i
    for i, w in enumerate(
        "zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen "
        "fifteen sixteen seventeen eighteen nineteen".split()
    )
}
UNITS["a"] = 1  # "released one Chinook and a steelhead"
TENS = {
    w: 10 * i
    for i, w in enumerate(
        "x x twenty thirty forty fifty sixty seventy eighty ninety".split()
    )
}
SPECIES = {
    "chinook": "Chinook Salmon",
    "coho": "Coho Salmon",
    "chum": "Chum Salmon",
    "pink": "Pink Salmon",
    "sockeye": "Sockeye Salmon",
    "steelhead": "Steelhead",
    "chinook jack": "Chinook Salmon (jack)",
    "coho jack": "Coho Salmon (jack)",
    "jack": "Jack (species not stated)", "jack chinook": "Chinook Salmon (jack)",
    "sturgeon": "Sturgeon", "oversize sturgeon": "Sturgeon", "sublegal sturgeon": "Sturgeon",
    "sub-legal sturgeon": "Sturgeon", "legal sturgeon": "Sturgeon", "white sturgeon": "Sturgeon",
    "chinook adult": "Chinook Salmon", "cutthroat": "Cutthroat Trout",
}


def num(word):
    w = word.lower().replace(",", "")
    if w.isdigit():
        return int(w)
    if w in UNITS:
        return UNITS[w]
    a, _, b = w.partition("-")
    if a in TENS and (not b or b in UNITS):
        return TENS[a] + (UNITS[b] if b else 0)
    raise ValueError(f"not a number: {word!r}")


def pdf_urls(html):
    paths = sorted(set(re.findall(r'href="(/sites/default/files/[^"]*\.pdf)"', html)))
    return [p for p in paths if re.search(r"/(%s)-\d\d/" % "|".join(YEARS), p)]


def fetch():
    PDFS.mkdir(parents=True, exist_ok=True)
    html = urllib.request.urlopen(INDEX, timeout=60).read().decode("utf-8", "replace")
    urls = pdf_urls(html)
    if not urls:
        sys.exit("fetch: the index page listed no PDFs")
    (ROOT / "urls.txt").write_text("\n".join(urls) + "\n")
    for u in urls:
        dest = PDFS / Path(u).name
        if not dest.exists() or not dest.stat().st_size:
            dest.write_bytes(urllib.request.urlopen(HOST + u, timeout=120).read())
            print("fetched", dest.name)


def week_from_name(stem, rd):
    """(start, end) of the week named in the file name, or None. The year comes
    from the report date, not the name: old names have no year or a mangled one."""
    toks = []
    for t in re.findall(r"[a-z]+|\d+", urllib.parse.unquote(stem).lower()):
        m = re.fullmatch(r"(\d{1,2})(20\d\d)", t)
        toks += list(m.groups()) if m else [t]
    seq = []
    for t in toks:
        if t.isdigit() and len(t) > 2:
            break
        if t.isdigit() or (t[:3] in MONTHS and len(t) >= 3 and t not in ("report", "reports")):
            seq.append(t)
    try:
        m1 = MONTHS[seq[0][:3]]
        d1 = int(seq[1])
        if seq[2].isdigit():
            m2, d2 = m1, int(seq[2])
        else:
            m2, d2 = MONTHS[seq[2][:3]], int(seq[3])
    except (IndexError, KeyError, ValueError):
        return None
    for year in (rd.year, rd.year - 1):
        try:
            end = datetime.date(year, m2, d2)
            start = datetime.date(year - 1 if m1 > m2 else year, m1, d1)
        except ValueError:
            continue
        if 0 <= (rd - end).days <= 10 and 4 <= (end - start).days <= 8:
            return start, end
    return None


def week_for(stem, rd):
    """(start, end, where it came from). With no usable name, the Monday to
    Sunday week before the report date: every report is dated 1-4 days after its week."""
    named = week_from_name(stem, rd)
    if named:
        return (*named, "file name")
    end = rd - datetime.timedelta(days=(rd.weekday() + 1) % 7 or 7)
    return end - datetime.timedelta(days=6), end, "report date"


def report_date(text):
    head = "\n".join(text.splitlines()[:15])
    for m in re.finditer(r"([A-Z][a-z]+)\.?\s+(\d{1,2}),?\s+(20\d\d)", head):
        mon = MONTHS.get(m.group(1).lower()[:3])
        if mon:
            return datetime.date(int(m.group(3)), mon, int(m.group(2)))
    m = re.search(r"\b(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})\b", head)
    if m:
        y = int(m.group(3))
        return datetime.date(y + 2000 if y < 100 else y, int(m.group(1)), int(m.group(2)))
    return None


HEADINGS = {
    "Salmon/Steelhead",
    "Sturgeon",
    "Shad",
    "Walleye",
    "Tributary Weir Report",
    "Additional resources",
    "Additional Resources",
    "Fishing regulations",
    "Mainstem Columbia River",
    "Columbia River Tributaries",
}
_RIVERS = (
    "Cowlitz|Kalama|Lewis|Washougal|Wind|Drano|Little White|Klickitat|Bonneville Pool|The Dalles Pool|"
    "John Day Pool|McNary Pool|Grays|Elochoman|Toutle|Green|Coweeman|Salmon Creek|Lacamas"
)
HEADER = re.compile(
    r"^((?:Sec(?:tion)?\s*\d+|(?:%s)|[A-Z][A-Za-z' ]*(?:River|Lake|Salmon|Pool))[^\u2014\u2013]*?)(?:\s*[\u2014\u2013]|\s+-)\s*(.+)$"
    % _RIVERS
)
# 2019-2020 reports write the Cowlitz reaches as "Cowlitz River - I-5 Br downstream - ..." and
# "Above the I-5 Br - ...".
COWLITZ = re.compile(r"^(?:Cowlitz River\s*[\u2014\u2013-]\s*)?(I-5 Br downstream|Above the I-5 Br)")


# Some reports run the next river onto the end of the previous entry's line.
MERGED = re.compile(
    r"(?<=\.)\s+(?=(?:Sec(?:tion)?\s*\d+\s*\([^)]*\)|(?:%s|[A-Z][A-Za-z' ]*(?:River|Lake|Salmon))(?: \([^)]*\))?)\s*[—–-])"
    % _RIVERS
)
# Obvious typos in WDFW's own text, fixed before parsing; the original stays in entries.line.
# Whole-word patterns: a bare "ffort" also sits inside the correct word "effort", which a plain replace turned into "eeffort".
TYPOS = {
    r"\brelased\b": "released",
    r"\bChiook\b": "Chinook",
    r"\bffort\b": "effort",
    r" and and ": " and ",
}


def fix_typos(text):
    for bad, good in TYPOS.items():
        text = re.sub(bad, good, text)
    return text


HEADINGS_LOWER = {h.lower() for h in HEADINGS}


def entries(text):
    """(heading name, joined body) for each line-wrapped entry in a Salmon/Steelhead block."""
    out, cur, in_block = [], None, True
    blank = page_break = False
    for raw in text.splitlines():
        line = raw.strip().lstrip("\u2022").strip()
        heading = line.rstrip(": ")
        line = COWLITZ.sub(lambda m: "Cowlitz River " + m.group(1), line)
        if line.startswith("Washington Department of Fish and Wildlife"):
            page_break = True
            continue
        if not line:
            blank = True
            continue
        # A paragraph after a blank line is not part of the entry above it (trailing
        # notes follow the last river), unless the blank was only a page break.
        if blank and not page_break and not HEADER.match(line):
            cur = None
        blank = page_break = False
        if heading.lower() in HEADINGS_LOWER:
            in_block = heading.lower() in ("salmon/steelhead", "mainstem columbia river", "columbia river tributaries")
            cur = None
            continue
        if not in_block:
            continue
        m = HEADER.match(line)
        if m and ":" in m.group(1):
            cur = None  # a regulation note ("Wind River: Effective ..."), not a creel entry
            continue
        if m:
            cur = [m.group(1).strip(), m.group(2).strip()]
            out.append(cur)
        elif cur:
            cur[1] += " " + line
    split = []
    for name, body in out:
        for i, piece in enumerate(MERGED.split(body)):
            if i == 0:
                split.append((name, piece))
            else:
                m = HEADER.match(piece)
                if m:
                    split.append((m.group(1).strip(), m.group(2).strip()))
                else:
                    split[-1] = (split[-1][0], split[-1][1] + " " + piece)
    return split


def classify(name):
    """(river, reach) for a wanted entry, 'skip' for the flight count, None for out of scope."""
    n = name.lower()
    if "weir" in n:
        return None
    if n.startswith("lower columbia river,"):
        return "skip"
    m = re.match(r"sec(?:tion)?\s*(\d+)\s*\(([^)]*)\)", n)
    if m:
        return "Lower Columbia", f"Sec {m.group(1)} ({m.group(2).strip().title()})"
    if n.startswith("cowlitz"):
        return "Cowlitz", "below I-5 Br" if "downstream" in n else "above I-5 Br"
    if n.startswith("lewis"):
        return "Lewis", ""
    if n.startswith("kalama"):
        return "Kalama", ""
    if n.startswith("washougal"):
        reach = re.search(r"\(([^)]*)\)", n)
        return "Washougal", reach.group(1).strip().title() if reach else ""
    if n.startswith("wind"):
        return "Wind", ""
    if n.startswith("drano") or n.startswith("little white"):
        return "Drano Lake", ""
    if n.startswith("klickitat"):
        if "below" in n:
            return "Klickitat", "below Fisher Hill Br"
        if "fishway" in n:
            return "Klickitat", "above #5 fishway"
        if "above" in n:
            return "Klickitat", "above Fisher Hill Br"
        return "Klickitat", ""
    return None


def species_list(chunk):
    """{species: count} from 'three coho, two Chinook jacks and one steelhead'."""
    got = {}
    for item in re.split(r",?\s*\band\b\s+|,\s*", chunk.strip(" ,.")):
        if not item:
            continue
        item = re.sub(r"\badults?\b\s*", "", item.strip(), flags=re.I).strip()
        m = re.fullmatch(r"([\d,]+|[a-z-]+)\s+(.+?)", item, re.I)
        if not m:
            raise ValueError(f"bad catch item {item!r}")
        key = (
            m.group(2).lower().rstrip("s")
            if m.group(2).lower().endswith(("jacks", "adults"))
            else m.group(2).lower()
        )
        if key not in SPECIES:
            raise ValueError(f"unknown species {m.group(2)!r}")
        got[SPECIES[key]] = got.get(SPECIES[key], 0) + num(m.group(1))
    return got


def parse_body(body: str) -> dict[str, Any]:
    """-> dict(status, bank, boat, anglers, kept{}, released{}); raises ValueError."""
    bank = boat = None
    kept, rel = {}, {}
    seen_catch = seen_nocatch = closed = False
    for s in re.split(r"(?<=\.)\s+", body.strip()):
        s = s.strip().rstrip(".").strip()
        if not s:
            continue
        if re.fullmatch(r"No [A-Za-z ]*(?:report|reported|sampled|effort)", s, re.I):
            continue
        if s.lower() == "closed":
            closed = True
            continue
        m = re.match(r"([\d,]+|[A-Za-z-]+) banks? (?:anglers?|rods?)\s*(.*)", s)
        if m:
            bank, rest = num(m.group(1)), m.group(2)
        else:
            m = re.match(
                r"([\d,]+|[A-Za-z-]+)\s*boats?\s*/\s*([\d,]+|[A-Za-z-]+) rods?\s*(.*)", s
            )
            if not m:
                raise ValueError(f"unrecognised sentence {s!r}")
            boat = (boat or 0) + num(m.group(2))
            rest = m.group(3)
        if rest in ("had no catch", "no catch"):
            seen_nocatch = True
            continue
        mk = re.fullmatch(r"kept (.+?)(?:,?\s*(?:and\s+)?released (.+))?", rest, re.I)
        mr = re.fullmatch(r"released (.+)", rest, re.I)
        if mk:
            for k, v in species_list(mk.group(1)).items():
                kept[k] = kept.get(k, 0) + v
            if mk.group(2):
                for k, v in species_list(mk.group(2)).items():
                    rel[k] = rel.get(k, 0) + v
        elif mr:
            for k, v in species_list(mr.group(1)).items():
                rel[k] = rel.get(k, 0) + v
        else:
            raise ValueError(f"unrecognised catch {rest!r}")
        seen_catch = True
    effort = None if bank is None and boat is None else (bank or 0) + (boat or 0)
    status = (
        "reported" if seen_catch else "no catch" if seen_nocatch
        else "closed" if closed else "no effort"
    )
    return dict(
        status=status, bank=bank, boat=boat, anglers=effort, kept=kept, released=rel
    )


SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE reports (pdf TEXT PRIMARY KEY, week_start TEXT, week_end TEXT, week_source TEXT,
                      report_date TEXT, url TEXT, text_chars INTEGER, entries INTEGER, note TEXT);
CREATE TABLE entries (id INTEGER PRIMARY KEY, pdf TEXT, river TEXT, reach TEXT, status TEXT,
                      bank_anglers INTEGER, boat_rods INTEGER, anglers INTEGER, line TEXT);
CREATE TABLE catch (entry_id INTEGER, species TEXT, kept INTEGER, released INTEGER);
CREATE TABLE flights (pdf TEXT, boats INTEGER, bank_rods INTEGER, line TEXT);
CREATE TABLE parse_failures (pdf TEXT, week TEXT, river TEXT, reason TEXT, line TEXT);
CREATE VIEW board AS
SELECT e.river || CASE WHEN e.reach = '' THEN '' ELSE ', ' || e.reach END AS River,
       COALESCE(c.species, CASE e.status WHEN 'no catch' THEN '(no catch)'
                                         WHEN 'not parsed' THEN '(not parsed)' END) AS Species,
       r.week_start || ' to ' || substr(r.week_end, 6) AS Week,
       e.anglers AS Anglers, c.kept AS Kept, c.released AS Released,
       CASE WHEN c.kept IS NOT NULL AND e.anglers > 0
            THEN round(c.kept * 100.0 / e.anglers, 1) END AS "Kept/100",
       e.bank_anglers AS Bank, e.boat_rods AS "Boat rods",
       r.report_date AS Reported, r.url AS Source, e.line AS "Report text"
FROM entries e JOIN reports r USING (pdf) LEFT JOIN catch c ON c.entry_id = e.id
WHERE e.status IN ('reported', 'no catch', 'not parsed')
ORDER BY r.week_start DESC, e.river, e.reach, c.species;
CREATE VIEW weeks AS
SELECT week_start || ' to ' || substr(week_end, 6) AS Week, report_date AS Reported,
       week_source AS "Week from", entries AS Entries, note AS Note, url AS Source
FROM reports ORDER BY week_start DESC;
CREATE VIEW not_parsed AS
SELECT COALESCE(r.week_start || ' to ' || substr(r.week_end, 6), '') AS Week, f.river AS River,
       f.reason AS Reason, f.line AS "Report text", r.url AS Source
FROM parse_failures f LEFT JOIN reports r USING (pdf) ORDER BY r.week_start DESC, f.river;
CREATE VIEW flight_counts AS
SELECT r.week_start || ' to ' || substr(r.week_end, 6) AS Week, f.boats AS Boats,
       f.bank_rods AS "Bank rods", r.report_date AS Reported, r.url AS Source, f.line AS "Report text"
FROM flights f JOIN reports r USING (pdf)
ORDER BY r.week_start DESC;
"""

CREEL = re.compile(r"bank\s+(?:anglers?|rods?)|boats?/\s*\d+\s*rods?", re.I)
FLIGHT = re.compile(
    r"([\d,]+|[A-Za-z-]+)\s+salmonid\s+boats(?:\s+and\s+([\d,]+|[A-Za-z-]+)\s+Washington\s+bank\s+rods)?", re.I
)
NO_FLIGHT = re.compile(r"No (?:flight|effort) count available", re.I)


def build():
    urls = {Path(u).name: u for u in (ROOT / "urls.txt").read_text().split()}
    db_tmp = DB.with_suffix(".db.new")
    db_tmp.unlink(missing_ok=True)
    con = sqlite3.connect(db_tmp)
    con.executescript(SCHEMA)
    con.execute(
        "INSERT INTO meta VALUES ('built_at', ?)",
        (datetime.datetime.now().isoformat(timespec="seconds"),),
    )
    for pdf in sorted(PDFS.glob("*.pdf")):
        text = subprocess.run(
            ["pdftotext", "-layout", str(pdf), "-"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        url = HOST + urls[pdf.name]
        rd = report_date(text)

        def fail(river, reason, line="", week=""):
            con.execute(
                "INSERT INTO parse_failures VALUES (?,?,?,?,?)",
                (pdf.name, week, river, reason, line),
            )

        if len(text.strip()) < 100:
            fail("", "no text layer (image-only PDF?)")
            continue
        if rd is None:
            fail("", "no report date found, so the week cannot be placed")
            continue
        ws, we, how = week_for(pdf.stem, rd)
        week = f"{ws} to {we}"
        found = entries(text)
        con.execute(
            "INSERT INTO reports VALUES (?,?,?,?,?,?,?,?,NULL)",
            (pdf.name, str(ws), str(we), how, str(rd), url, len(text), len(found)),
        )
        if not found:
            if CREEL.search(text):
                fail("", "creel counts in the text but no river entries found", week=week)
            else:
                con.execute("UPDATE reports SET note = 'no creel counts (regulation update)' WHERE pdf = ?", (pdf.name,))
            continue
        for name, body in found:
            cls = classify(name)
            if cls is None:
                continue
            line = f"{name} - {body}"
            if cls == "skip":
                m = FLIGHT.search(body)
                try:
                    if m:
                        boats = num(m.group(1))
                        rods = num(m.group(2)) if m.group(2) else None
                    elif NO_FLIGHT.search(body):
                        boats = rods = None
                    else:
                        raise ValueError("flight count sentence not recognised")
                    con.execute("INSERT INTO flights VALUES (?,?,?,?)", (pdf.name, boats, rods, line))
                except ValueError as err:
                    fail("Flight count", str(err), line, week)
                continue
            river, reach = cls
            try:
                p = parse_body(fix_typos(body))
            except ValueError as err:
                con.execute(
                    "INSERT INTO entries (pdf, river, reach, status, line) VALUES (?,?,?,?,?)",
                    (pdf.name, river, reach, "not parsed", line),
                )
                fail(f"{river} {reach}".strip(), str(err), line, week)
                continue
            cur = con.execute(
                "INSERT INTO entries (pdf, river, reach, status, bank_anglers, boat_rods, anglers, line)"
                " VALUES (?,?,?,?,?,?,?,?)",
                (pdf.name, river, reach, p["status"], p["bank"], p["boat"], p["anglers"], line),
            )
            for sp in sorted(set(p["kept"]) | set(p["released"])):
                con.execute(
                    "INSERT INTO catch VALUES (?,?,?,?)",
                    (cur.lastrowid, sp, p["kept"].get(sp), p["released"].get(sp)),
                )
    for pdf, river, reach, n in con.execute(
        "SELECT pdf, river, reach, count(*) FROM entries GROUP BY 1,2,3 HAVING count(*) > 1"
    ).fetchall():
        con.execute(
            "INSERT INTO parse_failures VALUES (?,?,?,?,?)",
            (pdf, "", f"{river} {reach}".strip(), f"{n} entries for the same river and reach", ""),
        )
    con.commit()
    con.close()
    db_tmp.replace(DB)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--fetch", action="store_true")
    if ap.parse_args().fetch:
        fetch()
    build()
    con = sqlite3.connect(DB)
    for label, q in [
        ("reports", "SELECT count(*) FROM reports"),
        ("entries", "SELECT count(*) FROM entries"),
        ("catch rows", "SELECT count(*) FROM catch"),
        ("parse failures", "SELECT count(*) FROM parse_failures"),
        ("board rows", "SELECT count(*) FROM board"),
        ("flight counts", "SELECT count(*) FROM flights"),
        ("weeks placed by report date", "SELECT count(*) FROM reports WHERE week_source = 'report date'"),
    ]:
        print(label, con.execute(q).fetchone()[0])
