"""Missing source facts are routed, never reconstructed from calories."""

import copy
import unittest

from common.incomplete_record_filter import assess_entry
from test_catalog_statistics import row


class IncompleteRecordFilterTest(unittest.TestCase):
    def test_plain_french_sugar_has_zero_proposal_but_is_not_approved(self):
        value = row(name='Sucre blanc')
        value['classification']['nutrition'].update(carbs=100, fat=None, protein=None, energy_kcal=400)
        original = copy.deepcopy(value)
        result = assess_entry(value)
        self.assertEqual(result['structural_zero_proposal'], {'fat': 0, 'protein': 0})
        self.assertEqual(result['route'], 'structural_zero_candidate_requires_verification')
        self.assertFalse(result['can_create_entry'])
        self.assertEqual(value, original)

    def test_energy_does_not_reconstruct_sprite_carbohydrates(self):
        value = row(name='Sprite')
        value['classification']['nutrition'].update(carbs=None, fat=0, protein=0, energy_kcal=9.2)
        result = assess_entry(value)
        self.assertEqual(result['route'], 'partial_nutrition_profile_required')
        self.assertEqual(result['structural_zero_proposal'], {})

    def test_all_missing_requires_whole_profile_even_for_sugar(self):
        value = row(name='Sucre blanc')
        value['classification']['nutrition'].update(carbs=None, fat=None, protein=None)
        self.assertEqual(assess_entry(value)['route'], 'whole_nutrition_profile_required')

    def test_flavored_sugar_is_not_plain_sugar(self):
        value = row(name='Sucre blanc aromatisé')
        value['classification']['nutrition'].update(carbs=100, fat=None, protein=None)
        self.assertEqual(assess_entry(value)['structural_zero_proposal'], {})

    def test_invalid_raw_missing_value_never_becomes_zero(self):
        value = row(name='Sucre blanc')
        value['classification']['nutrition'].update(carbs=100, fat=None, protein=None)
        value['record']['source_review_flags'] = ['invalid_fat']
        self.assertEqual(assess_entry(value)['structural_zero_proposal'], {})

    def test_missing_fiber_alone_does_not_make_profile_incomplete(self):
        result = assess_entry(row())
        self.assertEqual(result['missing_core'], [])
        self.assertEqual(result['route'], 'complete_profile_requires_import_metadata')
        self.assertIsNone(result['raw_missing_fields'])


if __name__ == '__main__':
    unittest.main()
