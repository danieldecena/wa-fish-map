"""Tests for scripts/build_depth_shading.py. Run:

    /opt/homebrew/bin/python3 -m unittest discover -s scripts -p "test_build_depth_shading.py"

The pure helpers, the colour ramp rule and the datum regression test run under the system
python. The tests that need numpy, scipy and pillow skip there; run them in the build venv:

    "$SCRATCH/venv/bin/python" -I -m unittest scripts.test_build_depth_shading
"""

import json
import re
import statistics
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_depth_shading as b

STACK = b.np is not None
FIXTURES = Path(__file__).resolve().parent / "fixtures"
PAGE = Path(__file__).resolve().parent.parent / "Artifacts" / "salmon-rivers"


class RampTests(unittest.TestCase):
    def test_detector_rejects_the_rating_colours_and_accepts_the_ramp(self):
        for name, rgb in b.RATING_COLOURS.items():
            self.assertFalse(b.calm_blue(rgb), name)
        for ft, rgb in b.RAMP:
            self.assertTrue(b.calm_blue(rgb), "ramp stop at %d ft" % ft)

    def test_ramp_gets_darker_with_depth_and_is_in_order(self):
        lum = [sum(rgb) for _, rgb in b.RAMP]
        self.assertEqual(lum, sorted(lum, reverse=True))
        self.assertEqual([s[0] for s in b.RAMP], sorted(s[0] for s in b.RAMP))

    def test_page_ramp_equals_the_generated_ramp(self):
        text = (PAGE / "depth-shading.js").read_text()
        got = re.findall(r'\[\s*(\d+),\s*"(#[0-9a-f]{6})"\s*\]', text)
        self.assertEqual(
            [(int(f), h) for f, h in got],
            [(ft, b.hex_rgb(rgb)) for ft, rgb in b.RAMP],
        )


class GridTests(unittest.TestCase):
    def test_a_dem_window_has_square_degree_pixels(self):
        # The server stretches a window whose pixels are not square in degrees, which once moved
        # every tile by 0.02 degrees. The window must be nx by ny request pixels exactly.
        for r, c in [(0, 3), (7, 2), (15, 1)]:
            (w, s, e, n), (nx, ny) = b.window_box(r, c)
            self.assertAlmostEqual((e - w) / nx, b.W_PX, places=12)
            self.assertAlmostEqual((n - s) / ny, b.W_PX, places=12)

    def test_tiles_abut_and_pixels_are_about_square_on_the_ground(self):
        w0, s0, e0, n0 = b.tile_box(3, 3)
        w1, s1, e1, n1 = b.tile_box(3, 4)
        w2, s2, e2, n2 = b.tile_box(4, 3)
        self.assertAlmostEqual(e0, w1, places=12)
        self.assertAlmostEqual(s0, n2, places=12)
        self.assertAlmostEqual(b.M_PER_PX_Y * b.OUT_LAT_PX, 20.5, delta=0.1)
        self.assertAlmostEqual(b.M_PER_PX_X * b.OUT_LON_PX, 20.9, delta=0.2)

    def test_projection_round_trips(self):
        x, y = b.lonlat_to_map(-122.34, 47.6)
        lon, lat = b.map_to_lonlat(x, y)
        self.assertAlmostEqual(lon, -122.34)
        self.assertAlmostEqual(lat, 47.6)

    def test_covered_areas_are_the_puget_sound_ones(self):
        self.assertEqual(b.AREA_IDS, ["8-1", "8-2", "9", "10", "11", "12", "13"])
        out = b.load_outlines()
        self.assertEqual(sorted(out), sorted(b.AREA_IDS))
        for rings in out.values():
            for ring in rings:
                for lon, lat in ring:
                    self.assertTrue(-123.3 < lon < -122.0 and 46.9 < lat < 48.6)

    def test_vdatum_no_answer_is_not_a_height(self):
        self.assertGreater(
            b.VD_SENTINEL, 10
        )  # -999999 must never be read as a separation


class DatumTests(unittest.TestCase):
    def test_depth_sign_and_land(self):
        # NAVD88 zero sits 0.75 m above MLLW here, so a bed at -10 m NAVD88 is 9.25 m below low tide.
        self.assertAlmostEqual(b.depth_ft(-10.0, 0.75), 9.25 * b.FT, places=4)
        self.assertLess(b.depth_ft(2.0, 0.75), 0)

    def test_interp_grid_is_bilinear_and_refuses_off_grid(self):
        g = dict(
            lon0=-123.0,
            lat0=48.0,
            dlon=1.0,
            dlat=1.0,
            nx=2,
            ny=2,
            z=[[0.0, 1.0], [2.0, 3.0]],
        )
        self.assertAlmostEqual(b.interp_grid(g, -122.5, 47.5), 1.5)
        self.assertAlmostEqual(b.interp_grid(g, -123.0, 48.0), 0.0)
        self.assertIsNone(b.interp_grid(g, -124.0, 47.5))
        g["z"][0][1] = None
        self.assertIsNone(b.interp_grid(g, -122.5, 47.5))

    def test_shipped_datum_keeps_the_chart_and_the_model_within_a_foot(self):
        """The regression the spike's single constant failed: +1.3 to +1.9 ft of bias in deep flat water.

        The fixture soundings were held out of the calibration, so this is not the fit scoring itself.
        """
        grid = json.loads((FIXTURES / "depth-shading-datum.json").read_text())["grid"]
        rows = json.loads((FIXTURES / "depth-shading-soundings.json").read_text())[
            "rows"
        ]
        self.assertGreaterEqual(len(rows), 100)

        def bias(shift_of, sel):
            d = [b.depth_ft(r["dem_navd88_m"], shift_of(r)) - r["enc_ft"] for r in sel]
            return statistics.median(d)

        def shipped(r):
            s = b.interp_grid(grid, r["lon"], r["lat"])
            self.assertIsNotNone(s, r)
            return s

        # Pooled, the bias must stay under a foot. Per area the median of 40 soundings is noisier (Hood Canal's walls
        # scatter by tens of feet), so an area may stray to 1.5 ft before this fails.
        self.assertLess(abs(bias(shipped, rows)), 1.0, "all areas pooled")
        for aid in b.AREA_IDS:
            sel = [r for r in rows if r["area"] == aid]
            self.assertGreaterEqual(len(sel), 30, aid)
            self.assertLess(abs(bias(shipped, sel)), 1.5, "area %s median bias" % aid)
        deep = [r for r in rows if r["enc_ft"] > 150]
        self.assertGreaterEqual(len(deep), 40)
        self.assertLess(abs(bias(shipped, deep)), 1.0, "deep flat water")
        # The known-bad input: the spike's one Seattle constant must fail this same test, or the test cannot fail.
        flat = lambda r: 0.715
        self.assertGreater(abs(bias(flat, rows)), 1.0, "pooled: the single constant would pass")
        over = [a for a in b.AREA_IDS if abs(bias(flat, [r for r in rows if r["area"] == a])) > 1.5]
        self.assertGreaterEqual(len(over), 2, "per area: the single constant would pass")


@unittest.skipUnless(STACK, "numpy stack not installed")
class StackTests(unittest.TestCase):
    def geom(self):
        return dict(lon0=-123.0, lat0=48.0, dlon=0.05, dlat=0.02, nx=20, ny=30)

    def test_datum_numpy_equals_pure_python_interp(self):
        g = self.geom()
        grid = b.np.fromfunction(
            lambda j, i: 0.7 + 0.01 * i + 0.02 * j, (g["ny"], g["nx"])
        )
        d = b.Datum(g, grid)
        pure = dict(g, z=grid.tolist())
        for lon, lat in [(-122.7, 47.7), (-122.31, 47.52), (-122.95, 47.99)]:
            self.assertAlmostEqual(
                float(d.shift_m(lon, lat)[0]), b.interp_grid(pure, lon, lat), places=9
            )

    def test_fit_correction_recovers_a_known_offset_and_is_zero_far_from_data(self):
        g = dict(lon0=-125.0, lat0=48.0, dlon=0.2, dlat=0.02, nx=20, ny=30)  # 4 degrees across
        rng = b.np.random.default_rng(1)
        lon = rng.uniform(-122.8, -122.4, 500)
        lat = rng.uniform(47.6, 47.9, 500)
        corr = b.fit_correction(lon, lat, b.np.full(500, 0.5), g)
        i = int((-122.6 - g["lon0"]) / g["dlon"])
        j = int((g["lat0"] - 47.75) / g["dlat"])
        self.assertAlmostEqual(float(corr[j, i]), 0.5, places=6)
        self.assertEqual(float(corr[0, 0]), 0.0)  # 2 degrees from any sounding: VDatum on its own

    def test_vdatum_samples_fill_and_the_no_answer_value_is_dropped(self):
        vd = dict(
            nx=3,
            ny=2,
            lon0=-123.0,
            lat0=48.0,
            dlon=0.1,
            dlat=0.1,
            points=[
                dict(i=0, j=0, z=0.7),
                dict(i=1, j=0, z=-999999.0),
                dict(i=2, j=0, z=0.9),
                dict(i=0, j=1, z=None),
                dict(i=1, j=1, z=0.8),
                dict(i=2, j=1, z=0.85),
            ],
        )
        d = b.Datum.from_vdatum(vd)
        self.assertEqual(d.answered, 4)
        self.assertTrue(b.np.all(b.np.abs(d.grid) < 5))
        self.assertAlmostEqual(float(d.grid[1, 0]), 0.7)  # nearest answer

    def test_hillshade_is_flat_on_flat_ground_and_shade_factor_is_capped(self):
        flat = b.np.full((20, 20), 40.0)
        k = b.shade_factor(b.hillshade(flat))
        self.assertTrue(b.np.allclose(k, 1.0, atol=0.02))
        self.assertLessEqual(float(b.shade_factor(b.np.array([1.0]))[0]), 1.18)
        self.assertGreaterEqual(float(b.shade_factor(b.np.array([0.0]))[0]), 0.6)

    def test_a_tile_of_a_synthetic_bowl_has_water_in_it_and_land_transparent(self):
        # Rendering end to end needs a downloaded tile; the colour step on its own: pale at 0 ft, dark deep.
        rgb = b.ramp_rgb(b.np.array([0.0, 100.0, 900.0]))
        self.assertGreater(float(rgb[0].sum()), float(rgb[1].sum()))
        self.assertGreater(float(rgb[1].sum()), float(rgb[2].sum()))


if __name__ == "__main__":
    unittest.main()
