"""Tests for the typo fixes and the "no effort" sentences in build_salmon_db.py.

    python3 -m unittest discover -s scripts -p "test_build_salmon_db.py"
"""

import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "sdb", Path(__file__).resolve().parent / "build_salmon_db.py"
)
sdb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sdb)


class FixTypos(unittest.TestCase):
    def test_the_word_effort_is_left_alone(self):
        for text in ("No effort.", "Light effort during the week.", "Little to no effort"):
            self.assertEqual(sdb.fix_typos(text), text)

    def test_the_typos_it_exists_for_are_fixed(self):
        self.assertEqual(sdb.fix_typos("No ffort."), "No effort.")
        self.assertEqual(sdb.fix_typos("relased one Chinook"), "released one Chinook")
        self.assertEqual(sdb.fix_typos("one Chiook jack"), "one Chinook jack")
        self.assertEqual(sdb.fix_typos("kept one and and two"), "kept one and two")

    def test_a_typo_inside_a_longer_word_is_not_touched(self):
        self.assertEqual(sdb.fix_typos("xrelasedx"), "xrelasedx")

    def test_no_effort_is_a_status_not_a_parse_failure(self):
        got = sdb.parse_body(sdb.fix_typos("No effort."))
        self.assertEqual(got["status"], "no effort")
        self.assertIsNone(got["anglers"])


if __name__ == "__main__":
    unittest.main()
