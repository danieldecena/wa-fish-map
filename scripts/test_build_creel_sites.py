"""Tests for the page-overlap rule in build_creel_sites.py.

    python3 -m unittest discover -s scripts -p "test_build_creel_sites.py"
"""

import importlib.util
import sys
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "csb", Path(__file__).resolve().parent / "build_creel_sites.py"
)
csb = importlib.util.module_from_spec(spec)
sys.modules["csb"] = csb  # dataclasses look their module up here
spec.loader.exec_module(csb)


def row(site="Ramp A", area="Area 10", date="2026-10-01", anglers=4, coho=2):
    return csb.SourceRow(site, area, date, 2, anglers, {"Coho": coho})


class PageOverlap(unittest.TestCase):
    def test_a_row_repeated_on_the_next_page_is_dropped(self):
        a, b = row(coho=2), row(site="Ramp B", coho=5)
        rows, dropped = csb.drop_page_overlap([[a, b], [row(coho=2), row(site="Ramp C")]])
        self.assertEqual(dropped, 1)
        self.assertEqual([r.site for r in rows], ["Ramp A", "Ramp B", "Ramp C"])

    def test_identical_rows_on_one_page_are_both_kept(self):
        rows, dropped = csb.drop_page_overlap([[row(), row()]])
        self.assertEqual((len(rows), dropped), (2, 0))

    def test_different_figures_are_not_a_repeat(self):
        rows, dropped = csb.drop_page_overlap([[row(coho=2)], [row(coho=3)]])
        self.assertEqual((len(rows), dropped), (2, 0))

    def test_totals_are_not_doubled_by_an_overlap(self):
        pages = [[row(coho=7)], [row(coho=7)]]
        rows, _ = csb.drop_page_overlap(pages)
        groups = csb.group_rows(rows)
        day = groups[0].days["2026-10-01"]
        self.assertEqual(day.species["Coho"], 7)


if __name__ == "__main__":
    unittest.main()
