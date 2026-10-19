"""Tests for the post-merge review fixes: repeated bank sentences, a malformed
no-match entry, the annual page's season in January, and the export's table-based row counts.

    python3 -m unittest discover -s scripts -p "test_review_fixes.py"
"""

import importlib.util
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, HERE / file)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod  # dataclasses look their module up here
    spec.loader.exec_module(mod)
    return mod


sdb = load("rf_sdb", "build_salmon_db.py")
creel = load("rf_creel", "build_creel_sites.py")
export = load("rf_export", "export_salmon_page.py")


class BankSentences(unittest.TestCase):
    def test_two_bank_sentences_add_up_like_boat_sentences(self):
        got = sdb.parse_body("5 bank anglers kept one coho. 3 bank anglers released two coho.")
        self.assertEqual(got["bank"], 8)
        self.assertEqual(got["anglers"], 8)


class Crosswalk(unittest.TestCase):
    def test_a_non_object_no_match_entry_stops_the_build_with_a_message(self):
        with self.assertRaises(SystemExit) as cm:
            creel.parse_crosswalk({"entries": [], "reviewed_no_match": ["Some Ramp"]}, set())
        self.assertIn("reviewed_no_match 1: not an object", str(cm.exception))


ANNUAL = """<select name="sample_date"><option value="1">{year}</option></select>
<table><caption>Oct 05, {year}</caption><thead><tr><th>Ramp/site</th><th>Catch area</th>
<th># Interviews (Boat or Shore)</th><th>Anglers</th></tr></thead>
<tbody><tr><td>Ramp A</td><td>Area 10</td><td>2</td><td>4</td></tr></tbody></table>"""
EMPTY = '<select name="sample_date"><option value="1">2025</option></select><table><tbody></tbody></table>'


class AnnualSeason(unittest.TestCase):
    def run_annual(self, newest, this_year):
        pages = {"puget-annual-newest-p0.html": ANNUAL.format(year=newest)}
        original = creel.fetch
        creel.fetch = lambda url, name, refresh: pages.get(name, EMPTY)
        try:
            return creel.fetch_annual(this_year, False)
        finally:
            creel.fetch = original

    def test_in_january_last_year_is_the_newest_and_the_build_goes_on(self):
        year, seen, bad = self.run_annual(2025, 2026)
        self.assertEqual((year, bad), (2025, []))
        self.assertEqual(seen, {"Ramp A": ("2025-10-05", 1)})

    def test_this_year_is_fine(self):
        self.assertEqual(self.run_annual(2026, 2026)[0], 2026)

    def test_a_season_that_is_neither_this_year_nor_last_is_refused(self):
        with self.assertRaises(SystemExit):
            self.run_annual(2023, 2026)


class ExportCounts(unittest.TestCase):
    def make_db(self, orphan_flight=False):
        path = Path(tempfile.mkdtemp()) / "s.db"
        con = sqlite3.connect(path)
        con.executescript(sdb.SCHEMA)
        con.execute("INSERT INTO meta VALUES ('built_at', '2026-10-18T00:00:00')")
        con.execute(
            "INSERT INTO reports VALUES ('a.pdf', '2026-10-05', '2026-10-11', 'file name', '2026-10-13', 'https://x/a.pdf', 100, 1, NULL)"
        )
        con.execute("INSERT INTO flights VALUES ('a.pdf', 3, 4, 'line')")
        if orphan_flight:
            con.execute("INSERT INTO flights VALUES ('gone.pdf', 1, 1, 'line')")
        con.commit()
        con.close()
        return path

    def test_a_clean_database_exports(self):
        out = Path(tempfile.mkdtemp()) / "data.js"
        export.export(self.make_db(), out)
        self.assertTrue(out.read_text().startswith("window.SALMON = "))

    def test_a_row_the_view_drops_stops_the_export(self):
        out = Path(tempfile.mkdtemp()) / "data.js"
        with self.assertRaises(SystemExit) as cm:
            export.export(self.make_db(orphan_flight=True), out)
        self.assertIn("flight_counts", str(cm.exception))
        self.assertFalse(out.exists())


if __name__ == "__main__":
    unittest.main()
