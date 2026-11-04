import copy
import unittest
from common.enrichment import validate_proposal


class EnrichmentTest(unittest.TestCase):
    def setUp(self):
        self.original = {"source_id": "00123", "nutrition_as_exported": {"carbs": None, "fiber": None, "fat": 2, "protein": None, "energy_kcal": None}}
        self.proposal = {"code": "00123", "status": "candidate", "sources": [{"url": "https://manufacturer.example/product", "matched_barcode": "00123", "basis_amount": 100, "basis_unit": "g", "nutrition": {"carbs": 4, "fiber": None, "fat": 2, "protein": 3, "energy_kcal": 46}}]}

    def test_only_missing_values_are_proposed_and_original_is_untouched(self):
        before = copy.deepcopy(self.original)
        result = validate_proposal(self.proposal, self.original)
        self.assertEqual(result["status"], "source_backed_proposal")
        self.assertEqual(result["patch"], {"carbs": 4, "protein": 3, "energy_kcal": 46})
        self.assertEqual(result["carbs_label_mode"], "unknown")
        self.assertFalse(result["publication_approved"])
        self.assertEqual(before, self.original)

    def test_unknown_status_cannot_bypass_validation(self):
        self.proposal["status"] = "source_backed_proposal"
        result = validate_proposal(self.proposal, self.original)
        self.assertEqual(result["status"], "hold")
        self.assertIn("invalid_research_status", result["errors"])
        self.assertEqual(result["patch"], {})

    def test_similar_name_without_exact_barcode_cannot_fill_macros(self):
        self.proposal["sources"][0]["matched_barcode"] = "123"
        result = validate_proposal(self.proposal, self.original)
        self.assertEqual(result["status"], "hold")
        self.assertEqual(result["patch"], {})

    def test_explicit_zero_is_preserved_but_missing_fiber_not_filled(self):
        self.proposal["sources"][0]["nutrition"]["carbs"] = 0
        result = validate_proposal(self.proposal, self.original)
        self.assertEqual(result["patch"]["carbs"], 0)
        self.assertNotIn("fiber", result["patch"])

    def test_ml_are_kept_as_ml_and_unknown_basis_is_blocked(self):
        self.proposal["sources"][0]["basis_unit"] = "ml"
        self.assertEqual(validate_proposal(self.proposal, self.original)["nutrition_basis"], {"amount": 100, "unit": "ml"})
        self.proposal["sources"][0]["basis_unit"] = None
        self.assertEqual(validate_proposal(self.proposal, self.original)["status"], "hold")

    def test_existing_macro_conflict_prevents_any_patch(self):
        self.proposal["sources"][0]["nutrition"]["fat"] = 8
        result = validate_proposal(self.proposal, self.original)
        self.assertIn("conflict_with_off_fat", result["errors"])
        self.assertEqual(result["patch"], {})

    def test_reported_identity_or_recipe_conflict_is_not_auto_accepted(self):
        self.proposal["conflicts"] = ["Source is a different package or recipe"]
        result = validate_proposal(self.proposal, self.original)
        self.assertEqual(result["status"], "hold")
        self.assertIn("research_reported_conflict", result["errors"])
        self.assertEqual(result["patch"], {})

    def test_conflicting_sources_and_invalid_numbers_are_blocked(self):
        another = copy.deepcopy(self.proposal["sources"][0])
        another["nutrition"]["carbs"] = 8
        self.proposal["sources"].append(another)
        self.assertEqual(validate_proposal(self.proposal, self.original)["status"], "hold")
        self.proposal["sources"] = [another]
        another["nutrition"]["fat"] = float('nan')
        self.assertEqual(validate_proposal(self.proposal, self.original)["status"], "hold")


if __name__ == '__main__':
    unittest.main()
