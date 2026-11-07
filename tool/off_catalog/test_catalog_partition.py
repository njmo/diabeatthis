"""Regression scenarios for the two-bucket publication preparation audit."""

import copy
import unittest

from common.catalog_partition import classify


def product():
    return {'id': 'maker_123', 'name': 'Jogurt naturalny', 'manufacturer': 'maker',
            'source_url': 'https://example.com/product/123', 'preparation': 'as_sold',
            'basis': {'amount': 100, 'unit': 'g'}, 'carbs_label_mode': 'unknown',
            'nutrition': {'carbs': 5, 'fat': 3, 'protein': 4, 'fiber': None, 'energy_kcal': 63},
            'publication_approved': False}


class CatalogPartitionTest(unittest.TestCase):
    def test_complete_source_is_consistent_but_unknown_convention_is_not_import_ready(self):
        row = product()
        original = copy.deepcopy(row)
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertEqual(result['group'], 'consistent_candidates')
        self.assertFalse(result['import_ready'])
        self.assertIn('carbohydrate_convention_unverified', result['import_blockers'])
        self.assertEqual(row, original)
        self.assertIsNone(result['nutrition']['fiber'])

    def test_missing_required_macro_never_becomes_zero(self):
        row = product()
        row['nutrition']['protein'] = None
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertIn('missing_protein', result['review_reasons'])
        self.assertIsNone(result['nutrition']['protein'])

    def test_milliliters_never_become_grams(self):
        row = product()
        row['basis']['unit'] = 'ml'
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertIn('volume_basis', result['review_reasons'])
        self.assertEqual(result['basis']['unit'], 'ml')

    def test_conflicting_same_name_and_unverified_snapshot_are_held(self):
        result = classify(product(), manufacturer=True, conflicting_name=True)
        self.assertEqual(result['group'], 'requires_review')
        self.assertIn('same_name_different_profiles', result['review_reasons'])
        self.assertIn('source_snapshot_not_verified', result['review_reasons'])

    def test_reported_energy_is_not_corrected_to_formula(self):
        row = product()
        row['nutrition']['energy_kcal'] = 273
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertIn('energy_requires_review', result['review_reasons'])
        self.assertEqual(result['nutrition']['energy_kcal'], 273)

    def test_fiber_contribution_avoids_false_energy_failure(self):
        row = product()
        row['nutrition'] = {'carbs': 20.1, 'fat': 4.7, 'protein': 16.5, 'fiber': 43.6, 'energy_kcal': 276}
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertNotIn('energy_requires_review', result['review_reasons'])

    def test_invalid_optional_values_and_mass_are_held(self):
        row = product()
        row['nutrition'].update(carbs=90, fat=20, fiber=-1)
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertIn('invalid_fiber', result['review_reasons'])
        self.assertIn('core_mass_above_100', result['review_reasons'])

    def test_complete_off_macros_do_not_prove_basis(self):
        row = product()
        row['nutrition_as_exported'] = row.pop('nutrition')
        result = classify(row)
        self.assertEqual(result['group'], 'requires_review')
        self.assertIn('off_label_requires_verification', result['review_reasons'])
        self.assertIn('unknown_nutrition_basis', result['review_reasons'])

    def test_explicit_eu_profile_needs_no_fiber_for_core_completeness(self):
        row = product()
        row.update(carbs_label_mode='eu', publication_approved=True)
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertTrue(result['import_ready'])
        self.assertIsNone(result['nutrition']['fiber'])

    def test_non_eu_profile_requires_fiber_to_compute_net_carbs(self):
        row = product()
        row.update(carbs_label_mode='non_eu', publication_approved=True)
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertFalse(result['import_ready'])
        self.assertIn('fiber_required_for_non_eu_conversion', result['import_blockers'])

    def test_unknown_convention_cannot_hide_excess_separate_fiber_mass(self):
        row = product()
        row['nutrition'] = {'carbs': 3.2, 'fat': 6.2, 'protein': 15, 'fiber': 77, 'energy_kcal': 283}
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertIn('fiber_mass_requires_review', result['review_reasons'])

    def test_non_eu_energy_does_not_count_fiber_as_four_kcal_carbs(self):
        row = product()
        row['carbs_label_mode'] = 'non_eu'
        row['nutrition'] = {'carbs': 80, 'fat': 0, 'protein': 0, 'fiber': 70, 'energy_kcal': 180}
        result = classify(row, manufacturer=True, source_verified=True)
        self.assertNotIn('energy_requires_review', result['review_reasons'])
        self.assertNotIn('fiber_mass_requires_review', result['review_reasons'])


if __name__ == '__main__':
    unittest.main()
