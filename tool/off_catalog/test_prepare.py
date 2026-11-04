import csv
import gzip
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

from common.products import NUTRIENTS, product_from_row, search_text
from prepare import prepare


def row(**changes):
    return {"code": "0012345678905", "countries_tags": "en:poland,en:germany",
            "product_name": "Łowicz jogurt", "brands": "Test", "quantity": "150 g",
            "carbohydrates_100g": "4.5", "fiber_100g": "", "fat_100g": "0",
            "proteins_100g": "5", "energy-kcal_100g": "38", **changes}


class ExportTest(unittest.TestCase):
    def test_market_filter_is_exact_not_language_or_prefix(self):
        self.assertIsNone(product_from_row(row(countries_tags="en:poland-other")))
        self.assertIsNone(product_from_row(row(countries_tags="", product_name="Polski produkt")))
        self.assertIsNotNone(product_from_row(row()))

    def test_identity_zero_missing_and_unknown_conventions_are_preserved(self):
        product = product_from_row(row())
        self.assertEqual(product["source_id"], "0012345678905")
        self.assertEqual(product["nutrition_as_exported"]["fat"], 0)
        self.assertIsNone(product["nutrition_as_exported"]["fiber"])
        self.assertEqual(product["nutrition_as_exported"]["carbs"], 4.5)
        self.assertEqual(product["nutrition_basis"], "unknown_100g_or_100ml")
        self.assertEqual(product["carbs_label_mode"], "unknown")
        self.assertFalse(product["import_ready"])
        self.assertIsNone(product["name_language"])

    def test_malformed_nutrition_never_becomes_zero_or_partial_number(self):
        for value in ("NaN", "inf", "-3", "<0.5", "2 g", "1,3"):
            product = product_from_row(row(fiber_100g=value))
            self.assertIsNone(product["nutrition_as_exported"]["fiber"])
            self.assertEqual(product["raw_nutrition"]["fiber_100g"], value)
            self.assertIn("invalid_fiber", product["review_flags"])
        self.assertIn("out_of_range_fat", product_from_row(row(fat_100g="101"))["review_flags"])

    def test_catalog_and_search_agree_with_review_and_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "fixture.gz"
            rows = [row(product_name="=Łowicz"), row(code="99", countries_tags="en:france")]
            with gzip.open(source, "wt", encoding="utf-8", newline="") as stream:
                writer = csv.DictWriter(stream, fieldnames=list(rows[0]), delimiter="\t")
                writer.writeheader()
                writer.writerows(rows)
            output = root / "out"
            manifest = prepare(source, output)
            self.assertEqual(manifest["counts"]["source_rows"], 2)
            self.assertEqual(manifest["counts"]["poland_products"], 1)
            output = output / "current"
            record = json.loads((output / "products-pl.jsonl").read_text())
            with sqlite3.connect(output / "catalog.sqlite") as db:
                result = db.execute("SELECT id FROM product_search WHERE product_search MATCH ?", (search_text("Łowicz"),)).fetchall()
                self.assertEqual(result, [(record["id"],)])
                self.assertEqual(json.loads(db.execute("SELECT document FROM products").fetchone()[0]), record)
            with (output / "review.csv").open() as stream:
                review = list(csv.DictReader(stream))
            self.assertEqual(review[0]["name"], "'=Łowicz")
            self.assertEqual(review[0]["fiber"], "")
            self.assertEqual(review[0]["fat"], "0.0")

    def test_invalid_poland_identity_is_counted_and_failed_run_keeps_current(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "fixture.gz"
            rows = [row(), row(code="bad-code")]
            with gzip.open(source, "wt", encoding="utf-8", newline="") as stream:
                writer = csv.DictWriter(stream, fieldnames=list(rows[0]), delimiter="\t")
                writer.writeheader()
                writer.writerows(rows)
            output = root / "out"
            manifest = prepare(source, output)
            self.assertEqual(manifest["counts"]["poland_invalid_identity"], 1)
            original = (output / "current").resolve()
            with gzip.open(source, "wt") as stream:
                stream.write("wrong_header\n")
            with self.assertRaises(ValueError):
                prepare(source, output)
            self.assertEqual((output / "current").resolve(), original)
            self.assertEqual(json.loads((original / "manifest.json").read_text()), manifest)

    def test_truncated_source_does_not_publish_catalog(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "truncated.gz"
            source.write_bytes(gzip.compress(b"code\tcountries_tags\n")[:-5])
            with self.assertRaises((ValueError, EOFError)):
                prepare(source, root / "out")
            self.assertFalse((root / "out/catalog.sqlite").exists())

    def test_missing_columns_fail_instead_of_empty_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "wrong.gz"
            with gzip.open(source, "wt") as stream:
                stream.write("code\tcountries_tags\n12\ten:poland\n")
            with self.assertRaisesRegex(ValueError, "Missing export columns"):
                prepare(source, root / "out")


if __name__ == "__main__":
    unittest.main()
