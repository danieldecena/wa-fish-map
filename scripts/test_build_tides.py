"""Tests for build_tides.py (no network).

    python3 -m unittest discover -s scripts -p "test_build_tides.py"
"""

import copy
import datetime
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "bt", Path(__file__).resolve().parent / "build_tides.py"
)
bt = importlib.util.module_from_spec(spec)
sys.modules["bt"] = bt
spec.loader.exec_module(bt)

FIXTURE = (
    Path(__file__).resolve().parent.parent
    / "Artifacts" / "salmon-rivers" / "test" / "fixtures" / "noaa-seattle.json"
)


def noaa():
    return json.loads(FIXTURE.read_text())


class Parse(unittest.TestCase):
    def test_rows_become_time_type_feet(self):
        rows = bt.parse_predictions(noaa(), "9447130")
        self.assertEqual(rows[0], ["2026-10-26 06:01", "H", 11.28])
        self.assertTrue(all(r[1] in ("H", "L") and isinstance(r[2], float) for r in rows))

    def test_error_object_is_rejected(self):
        with self.assertRaisesRegex(bt.BuildError, "No data was found"):
            bt.parse_predictions({"error": {"message": "No data was found"}}, "1234567")

    def test_empty_station_is_rejected(self):
        with self.assertRaisesRegex(bt.BuildError, "no predictions"):
            bt.parse_predictions({"predictions": []}, "1234567")

    def test_bad_type_time_or_height_is_rejected(self):
        for bad in ({"t": "2026-10-26 06:01", "v": "1", "type": "X"},
                    {"t": "10/26 06:01", "v": "1", "type": "H"},
                    {"t": "2026-10-26 06:01", "v": "x", "type": "H"}):
            with self.assertRaises(bt.BuildError):
                bt.parse_predictions({"predictions": [bad]}, "1234567")

    def test_non_monotonic_series_is_rejected(self):
        j = noaa()
        j["predictions"][2], j["predictions"][3] = j["predictions"][3], j["predictions"][2]
        with self.assertRaisesRegex(bt.BuildError, "not increasing"):
            bt.parse_predictions(j, "9447130")
        j = noaa()
        j["predictions"].append(copy.deepcopy(j["predictions"][-1]))
        with self.assertRaisesRegex(bt.BuildError, "not increasing"):
            bt.parse_predictions(j, "9447130")

    def test_query_matches_what_the_page_used(self):
        u = bt.query_url("9447130", datetime.date(2026, 10, 26), datetime.date(2026, 12, 9))
        for kv in ("product=predictions", "datum=MLLW", "interval=hilo", "units=english",
                   "time_zone=lst_ldt", "format=json", "station=9447130",
                   "begin_date=20261026", "end_date=20261209"):
            self.assertIn(kv, u)


def fake_fetcher(start, days):
    """One H and one L per day for any station, no network."""
    def f(sid, s, e):
        rows = []
        for i in range((e - s).days + 1):
            d = (s + datetime.timedelta(days=i)).isoformat()
            rows += [[d + " 05:00", "H", 9.0], [d + " 11:00", "L", 1.0]]
        return rows
    return f


class BuildAndValidate(unittest.TestCase):
    def setUp(self):
        self.start = datetime.date(2026, 10, 26)

    def test_build_covers_every_station_and_day(self):
        b = bt.build(self.start, 10, fetcher=fake_fetcher(self.start, 10))
        self.assertEqual(bt.validate(b), 10)
        self.assertEqual(b["end"], "2026-11-04")
        self.assertEqual([s["id"] for s in b["stations"]], [s[0] for s in bt.STATIONS])
        self.assertTrue(all(len(s["id"]) == 7 for s in b["stations"]))

    def test_validate_catches_a_missing_day_and_an_empty_station(self):
        b = bt.build(self.start, 10, fetcher=fake_fetcher(self.start, 10))
        gap = copy.deepcopy(b)
        sid = gap["stations"][0]["id"]
        gap["predictions"][sid] = [r for r in gap["predictions"][sid] if not r[0].startswith("2026-10-30")]
        with self.assertRaisesRegex(bt.BuildError, "2026-10-30"):
            bt.validate(gap)
        empty = copy.deepcopy(b)
        empty["predictions"][sid] = []
        with self.assertRaisesRegex(bt.BuildError, "no predictions"):
            bt.validate(empty)

    def test_a_short_fetch_is_refused(self):
        def short(sid, s, e):
            return [["2026-10-26 05:00", "H", 9.0], ["2026-10-27 05:00", "H", 9.0]]
        with self.assertRaisesRegex(bt.BuildError, "wanted"):
            bt.build(self.start, 10, fetcher=short)

    def test_render_round_trips_compact(self):
        b = bt.build(self.start, 3, fetcher=fake_fetcher(self.start, 3))
        text = bt.render(b)
        self.assertIn("Generated", text.splitlines()[0])
        self.assertNotIn("\n  ", text)
        self.assertEqual(bt.parse_file(text), b)


class AtomicWrite(unittest.TestCase):
    def test_failure_leaves_the_old_file_and_no_temp(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "tides-data.js"
            out.write_text("old")
            orig = bt.fetch

            def boom(*a):
                raise bt.BuildError("9447130: request failed: down")
            bt.fetch = boom
            try:
                rc = bt.main(["--out", str(out), "--start", "2026-10-26", "--days", "3"])
            finally:
                bt.fetch = orig
            self.assertEqual(rc, 1)
            self.assertEqual(out.read_text(), "old")
            self.assertEqual([p.name for p in Path(d).iterdir()], ["tides-data.js"])

    def test_write_replaces_whole_file_and_check_mode_reads_it(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "tides-data.js"
            b = bt.build(datetime.date(2026, 10, 26), 3, fetcher=fake_fetcher(None, 3))
            bt.write_atomic(out, bt.render(b))
            self.assertEqual(bt.main(["--check", "--out", str(out)]), 0)
            self.assertEqual([p.name for p in Path(d).iterdir()], ["tides-data.js"])
            out.write_text("window.TIDES={};\n")
            self.assertEqual(bt.main(["--check", "--out", str(out)]), 1)


if __name__ == "__main__":
    unittest.main()
