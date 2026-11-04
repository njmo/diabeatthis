import unittest
from pathlib import Path

from common.usda import convert, quality_issues
from common.icons import IconCatalog
from common.selection import select_group


def source_food():
    return {
        "fdcId": 123,
        "description": "Potatoes, boiled",
        "foodPortions": [{"gramWeight": 150}],
        "foodNutrients": [
            {"nutrient": {"id": key, "unitName": unit}, "amount": amount}
            for key, unit, amount in [(1003, "g", 2), (1004, "g", 0.1), (1005, "g", 20), (1079, "g", 2), (1008, "kcal", 85)]
        ],
    }


class CatalogTests(unittest.TestCase):
    def test_basic_catalog_excludes_uncooked_starches_and_composite_foods(self):
        for name in ["Rice, white, raw", "Rice, brown, uncooked", "Pasta, dry, enriched", "Pasta, fresh-refrigerated, plain, as purchased", "Noodles, egg, dry", "Ravioli, cheese-filled", "Cookies, plain", "Jams and preserves", "Potatoes, raw"]:
            food = {"fdcId": 1, "description": name, "foodCategory": {"description": "Vegetables and Vegetable Products" if name.startswith("Potatoes") else "Cereal Grains and Pasta"}}
            with self.subTest(name=name):
                self.assertIsNone(select_group(food, "sr_legacy"))
        for name in ["Rice, white, long-grain, cooked", "Rice, brown, medium-grain, cooked", "Pasta, cooked, enriched, without added salt"]:
            food = {"fdcId": 1, "description": name, "foodCategory": {"description": "Cereal Grains and Pasta"}}
            self.assertEqual(select_group(food, "sr_legacy"), "cooked_grain_or_pasta")
        food = {"fdcId": 1, "description": "Tomatoes, red, ripe, raw", "foodCategory": {"description": "Vegetables and Vegetable Products"}}
        self.assertEqual(select_group(food, "sr_legacy"), "vegetable")

    def test_icons_follow_the_food_instead_of_a_secondary_ingredient(self):
        icons = IconCatalog(Path(__file__).resolve().parents[2])
        for name, expected in [("Apple juice, unsweetened", "drink"), ("Chocolate milk, fat free", "milk"), ("Ravioli, cheese-filled, with tomato sauce", "pasta"), ("Beef, ground, cooked", "cut_of_meat"), ("Bread, with cheese", "bread")]:
            with self.subTest(name=name):
                self.assertEqual(icons.match(name)["iconId"], expected)
        self.assertEqual(icons.match("Cheese, cheddar, sliced")["iconId"], "wicked_cheddar_cheese")

    def test_us_total_carbs_are_not_reduced_or_scaled_by_portion(self):
        doc = convert(source_food(), "fndds")
        self.assertEqual(doc["carbsPer100g"], 20)
        self.assertEqual(doc["fiberPer100g"], 2)
        self.assertEqual(doc["carbsLabelMode"], "non_eu")
        self.assertEqual(doc["nutritionBasisGrams"], 100)
        self.assertNotIn("foodPortions", doc)
        self.assertNotIn("portions", doc)
        self.assertFalse(doc["isReference"])
        self.assertEqual(quality_issues(doc), [])

    def test_missing_is_distinct_from_measured_zero(self):
        food = source_food()
        food["foodNutrients"] = food["foodNutrients"][:3]
        doc = convert(food, "sr_legacy")
        self.assertIsNone(doc["fiberPer100g"])
        self.assertIn("missing:fiberPer100g", quality_issues(doc))
        food["foodNutrients"].append({"nutrient": {"id": 1079, "unitName": "g"}, "amount": 0})
        self.assertEqual(convert(food, "sr_legacy")["fiberPer100g"], 0)

    def test_invalid_values_and_units_are_rejected(self):
        for amount in [True, "1", -1, float("nan"), float("inf")]:
            food = source_food()
            food["foodNutrients"][0]["amount"] = amount
            with self.subTest(amount=amount), self.assertRaises(ValueError):
                convert(food, "fndds")
        food = source_food()
        food["foodNutrients"][0]["nutrient"]["unitName"] = "mg"
        with self.assertRaises(ValueError):
            convert(food, "fndds")

    def test_alcohol_and_unusual_energy_are_reviewed_without_changing_source(self):
        food = source_food()
        food["foodNutrients"].append({"nutrient": {"id": 1018, "unitName": "g"}, "amount": 10})
        doc = convert(food, "fndds")
        self.assertIn("contains_alcohol", quality_issues(doc))
        self.assertEqual(doc["kcalPer100g"], 85)
        food = source_food()
        food["foodNutrients"][4]["amount"] = 0
        doc = convert(food, "fndds")
        self.assertIn("energy_difference_review", quality_issues(doc))
        self.assertEqual(doc["kcalPer100g"], 0)


if __name__ == "__main__":
    unittest.main()
