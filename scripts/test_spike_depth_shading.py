"""Tests for the depth-shading spike's pure helpers.

They need numpy, scikit-image and friends, which the system python on this Mac
does not have, so the whole module skips there. Run them in the spike's venv:

    "$SCRATCH/venv/bin/python" -I -m unittest scripts.test_spike_depth_shading
"""

import colorsys
import importlib.util
import math
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("spike", HERE / "spike_depth_shading.py")
spike = importlib.util.module_from_spec(spec)
spec.loader.exec_module(spike)
STACK = spike.np is not None


def calm_blue(rgb):
    """A blue (hue 185-235) that is not the rating blue: well away from #0088ff in RGB.

    Hue alone cannot do it, since the rating blue sits at 208 degrees too.
    """
    h, _, _ = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    return 185 <= h * 360 <= 235 and math.dist(rgb, (0, 136, 255)) > 100


class RampTests(unittest.TestCase):
    def test_detector_rejects_the_rating_colours_and_accepts_the_ramp(self):
        for name, rgb in {
            "prime red": (255, 56, 60),
            "good orange": (255, 141, 40),
            "fair yellow": (255, 204, 0),
            "slow blue": (0, 136, 255),
        }.items():
            self.assertFalse(calm_blue(rgb), name)
        for ft, rgb in spike.RAMP:
            self.assertTrue(calm_blue(rgb), "ramp stop at %d ft" % ft)

    def test_ramp_gets_darker_with_depth(self):
        lum = [sum(rgb) for _, rgb in spike.RAMP]
        self.assertEqual(lum, sorted(lum, reverse=True))


class PathTests(unittest.TestCase):
    def test_enc_path_parses_relative_steps_to_lonlat(self):
        line = spike.parse_enc_path("M15148 32617l7 -8 14 -6")[0]
        self.assertEqual(len(line), 3)
        lon, lat = line[0]
        self.assertAlmostEqual(lon, -125.0 + 151.48 / spike.KX)
        self.assertAlmostEqual(lat, 49.1 - 326.17 / spike.KY)
        self.assertAlmostEqual(line[2][0], -125.0 + (151.48 + 0.21) / spike.KX)

    def test_depth_data_file_parses_and_sits_in_the_pacific_northwest(self):
        levels, labs = spike.load_depthdata()
        self.assertEqual(sorted(levels), spike.LEVELS_FT)
        for ft, lines in levels.items():
            for line in lines[:50]:
                for lon, lat in line:
                    self.assertTrue(
                        -125.2 < lon < -121.0 and 45.0 < lat < 49.2, (ft, lon, lat)
                    )
        self.assertGreater(len(labs), 1000)

    def test_datum_shift_sign_and_land(self):
        if not STACK:
            self.skipTest("numpy stack not installed")
        ft = spike.depth_ft_from_navd88(spike.np.array([-10.0, 2.0]), 0.729)
        self.assertAlmostEqual(float(ft[0]), (10 - 0.729) * spike.FT, places=4)
        self.assertLess(float(ft[1]), 0)


@unittest.skipUnless(STACK, "numpy stack not installed")
class ContourTests(unittest.TestCase):
    def test_cone_contours_are_rings_at_the_right_radius_and_round_trip(self):
        np = spike.np
        n = 400
        yy, xx = np.mgrid[0:n, 0:n]
        r = np.hypot(xx - 200, yy - 200)
        depth = 100 - r  # 100 ft in the middle, 0 at r=100
        bbox = (-122.5, 47.2, -122.4, 47.3)
        paths, polys = spike.contour_paths(depth, bbox, 0.005, 1.0, 0.5, 10)
        ring = polys[30][0]
        # 30 ft sits at r = 70 px of 400 across 0.1 deg of longitude
        lon_c = -122.45
        lat_c = 47.25
        rad_lon = np.abs(ring[:, 0] - lon_c).max()
        self.assertAlmostEqual(rad_lon, 70 / n * 0.1, delta=0.1 / n * 2)
        # the page-format string parses back to the same ring within one path unit
        back = spike.parse_enc_path(paths[30], 0.005)[0]
        self.assertAlmostEqual(
            back[0][1], float(ring[0, 1]), delta=0.005 / spike.KY * 1.01
        )
        self.assertTrue(math.isfinite(lat_c))

    def test_a_flat_floor_makes_no_contours(self):
        np = spike.np
        paths, _ = spike.contour_paths(
            np.full((100, 100), 45.0), (-122.5, 47.2, -122.4, 47.3), 0.005, 1.0, 0.5, 10
        )
        self.assertTrue(all(p == "" for p in paths.values()))


if __name__ == "__main__":
    unittest.main()
