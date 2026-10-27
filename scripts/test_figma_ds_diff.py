"""Tests for figma_ds_diff: a known-good pair must pass and each kind of drift must fire."""
import copy
import os
import tempfile
import unittest

import figma_ds_diff as d

MANIFEST = {
    "colors": {"rating.prime": {"light": "#ff383c", "dark": "#ff4245"}},
    "radii": {"surface.chromeRadius": 14.0},
    "type": {"badge": {"size": 12.0, "weight": "bold"}},
}
INVENTORY = {
    "variables": [
        {"id": "V1", "name": "rating/prime", "collection": "Color", "type": "COLOR",
         "values": {"Light": "#ff383c", "Dark": "#ff4245"}},
        {"id": "V2", "name": "radius/chrome", "collection": "Radius", "type": "FLOAT",
         "values": {"Value": 14}},
    ],
    "textStyles": [{"id": "S1", "name": "Badge", "family": "Inter", "style": "Bold",
                    "size": 12, "lineHeight": {"unit": "AUTO"}}],
    "components": [{"id": "C1", "name": "Rating Badge", "type": "COMPONENT_SET",
                    "description": "RatingBadge in WAFishMap/Views/RatingBadge.swift"}],
}
MAP = {
    "colors": {"rating.prime": "rating/prime"},
    "radii": {"surface.chromeRadius": "radius/chrome"},
    "type": {"badge": "Badge"},
    "modes": {"light": "Light", "dark": "Dark"},
    "ignoreVariables": [],
}


class DiffTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.root, "WAFishMap/Views"))
        open(os.path.join(self.root, "WAFishMap/Views/RatingBadge.swift"), "w").close()

    def run_diff(self, manifest=MANIFEST, inventory=INVENTORY, token_map=MAP):
        return d.diff(manifest, inventory, token_map, self.root)

    def kinds(self, rows):
        return sorted(r["kind"] for r in rows)

    def test_known_good_pair_has_no_drift(self):
        self.assertEqual(self.run_diff(), [])

    def test_one_unit_rounding_is_not_drift(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"][0]["values"]["Light"] = "#ff383d"
        self.assertEqual(self.run_diff(inventory=inv), [])

    def test_color_drift_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"][0]["values"]["Dark"] = "#ff3b30"
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["color"])

    def test_missing_variable_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"] = inv["variables"][1:]
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["missing-variable"])

    def test_unmapped_figma_variable_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"].append({"id": "V9", "name": "rating/extra", "collection": "Color",
                                 "type": "COLOR", "values": {"Light": "#000000", "Dark": "#000000"}})
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["unmapped-variable"])

    def test_ignored_variable_does_not_fire(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"].append({"id": "V9", "name": "map/water", "collection": "Color",
                                 "type": "COLOR", "values": {"Light": "#000000", "Dark": "#000000"}})
        m = copy.deepcopy(MAP)
        m["ignoreVariables"] = ["map/water"]
        self.assertEqual(self.run_diff(inventory=inv, token_map=m), [])

    def test_radius_drift_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["variables"][1]["values"]["Value"] = 12
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["radius"])

    def test_type_size_and_weight_fire(self):
        inv = copy.deepcopy(INVENTORY)
        inv["textStyles"][0].update(size=11, style="Semi Bold")
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["type-size", "type-weight"])

    def test_missing_style_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["textStyles"] = []
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["missing-style"])

    def test_description_naming_a_missing_file_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["components"][0]["description"] = "RatingBadge in WAFishMap/Views/Gone.swift"
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["description"])

    def test_description_with_no_swift_path_fires(self):
        inv = copy.deepcopy(INVENTORY)
        inv["components"][0]["description"] = "A badge."
        self.assertEqual(self.kinds(self.run_diff(inventory=inv)), ["description"])

    def test_bare_swift_file_name_resolves(self):
        inv = copy.deepcopy(INVENTORY)
        inv["components"][0]["description"] = "RatingBadge in RatingBadge.swift"
        self.assertEqual(self.run_diff(inventory=inv), [])

    def test_color_mapped_to_a_number_reports_instead_of_crashing(self):
        m = copy.deepcopy(MAP)
        m["colors"]["rating.prime"] = "radius/chrome"
        rows = self.run_diff(token_map=m)
        self.assertIn("type-mismatch", self.kinds(rows))

    def test_icon_components_need_no_swift_path(self):
        inv = copy.deepcopy(INVENTORY)
        inv["components"].append({"id": "C2", "name": "Icon/fish.fill", "type": "COMPONENT", "description": ""})
        self.assertEqual(self.run_diff(inventory=inv), [])

    def test_empty_inventory_is_an_error_not_a_pass(self):
        with self.assertRaises(ValueError):
            self.run_diff(inventory={"variables": [], "textStyles": [], "components": []})


    def alpha_pair(self, figma_light, figma_dark):
        man = copy.deepcopy(MANIFEST)
        man["colors"]["rating.prime"].update(lightAlpha=0.16, darkAlpha=0.32)
        inv = copy.deepcopy(INVENTORY)
        inv["variables"][0]["alphas"] = {"Light": figma_light, "Dark": figma_dark}
        return man, inv

    def test_matching_alpha_with_float_noise_passes(self):
        man, inv = self.alpha_pair(0.1599999964237213, 0.3199999928474426)
        self.assertEqual(self.run_diff(manifest=man, inventory=inv), [])

    def test_alpha_mismatch_fires(self):
        man, inv = self.alpha_pair(0.32, 0.3199999928474426)
        self.assertEqual(self.kinds(self.run_diff(manifest=man, inventory=inv)), ["alpha"])

    def test_description_html_entities_are_unescaped(self):
        inv = copy.deepcopy(INVENTORY)
        inv["components"][0]["description"] = "RatingBadge in &quot;RatingBadge.swift&quot;"
        self.assertEqual(self.run_diff(inventory=inv), [])


if __name__ == "__main__":
    unittest.main()
