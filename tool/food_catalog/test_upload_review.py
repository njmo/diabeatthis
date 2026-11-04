import unittest
from pathlib import Path

from common.icons import IconCatalog
from common.selection import select_group


class UploadReviewTests(unittest.TestCase):
    def test_common_oils_are_kept_without_exotic_or_blended_oils(self):
        for name, expected in [
            ("Oil, olive, salad or cooking", "fat_or_oil"),
            ("Oil, sunflower, linoleic (approx. 65%)", "fat_or_oil"),
            ("Oil, canola", "fat_or_oil"),
            ("Oil, corn, peanut, and olive", None),
            ("Oil, corn and canola", None),
            ("Oil, cupu assu", None),
            ("Oil, ucuhuba butter", None),
        ]:
            with self.subTest(name=name):
                self.assertEqual(select_group({"fdcId": 1, "description": name, "foodCategory": {"description": "Fats and Oils"}}, "sr_legacy"), expected)

    def test_exotic_meat_and_prepared_pate_are_excluded(self):
        for name, expected in [
            ("Game meat, rabbit, cooked, roasted", "cooked_meat_or_fish"),
            ("Game meat, deer, cooked, roasted", "cooked_meat_or_fish"),
            ("Game meat, raccoon, cooked, roasted", None),
            ("Game meat, squirrel, cooked, roasted", None),
            ("Emu, cooked", None),
            ("Pate de foie gras, canned", None),
        ]:
            with self.subTest(name=name):
                self.assertEqual(select_group({"fdcId": 1, "description": name, "foodCategory": {"description": "Poultry Products"}}, "sr_legacy"), expected)

    def test_flour_uses_a_flour_illustration(self):
        icons = IconCatalog(Path(__file__).resolve().parents[2])
        for name in ["Rice flour, brown", "Chickpea flour (besan)", "Wheat flours, bread, unenriched"]:
            self.assertEqual(icons.match(name)["iconId"], "wicked_white_flour")
        self.assertEqual(icons.match("Corn flour, whole-grain, blue")["iconId"], "wicked_corn_flour")


if __name__ == "__main__":
    unittest.main()
