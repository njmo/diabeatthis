"""Checks for the narrowed everyday-food catalog; existing tests stay intact."""

import unittest

from common.selection import select_group


class BasicSelectionTests(unittest.TestCase):
    def classify(self, name, category):
        return select_group({"fdcId": 1, "description": name, "foodCategory": {"description": category}}, "sr_legacy")

    def test_mushrooms_algae_spices_and_unusual_powders_are_excluded(self):
        for name, category in [
            ("Mushrooms, white, raw", "Vegetables and Vegetable Products"),
            ("Fungi, Cloud ears, dried", "Vegetables and Vegetable Products"),
            ("Seaweed, spirulina, dried", "Vegetables and Vegetable Products"),
            ("Spices, chervil, dried", "Spices and Herbs"),
            ("Spices, allspice, ground", "Spices and Herbs"),
            ("Baobab powder", "Fruits and Fruit Juices"),
            ("Yeast extract spread", "Vegetables and Vegetable Products"),
        ]:
            with self.subTest(name=name):
                self.assertIsNone(self.classify(name, category))

    def test_plain_flour_and_breadcrumbs_are_included(self):
        for name, category, expected in [
            ("Wheat flour, white, all-purpose, unenriched", "Cereal Grains and Pasta", "flour"),
            ("Rice flour, white, unenriched", "Cereal Grains and Pasta", "flour"),
            ("Chickpea flour (besan)", "Legumes and Legume Products", "flour"),
            ("Bread, crumbs, dry, grated, plain", "Baked Products", "breadcrumbs"),
        ]:
            with self.subTest(name=name):
                self.assertEqual(self.classify(name, category), expected)

    def test_low_macro_vegetables_are_retained_and_dry_pasta_is_excluded(self):
        self.assertEqual(self.classify("Cucumber, with peel, raw", "Vegetables and Vegetable Products"), "vegetable")
        self.assertEqual(self.classify("Cucumber, peeled, raw", "Vegetables and Vegetable Products"), "vegetable")
        self.assertEqual(self.classify("Lettuce, green leaf, raw", "Vegetables and Vegetable Products"), "vegetable")
        self.assertIsNone(self.classify("Pasta, dry, enriched", "Cereal Grains and Pasta"))
        self.assertIsNone(self.classify("Rice, white, long-grain, regular, raw, unenriched", "Cereal Grains and Pasta"))


if __name__ == "__main__":
    unittest.main()
