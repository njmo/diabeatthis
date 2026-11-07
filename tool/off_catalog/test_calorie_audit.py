import copy
import unittest

from common.calorie_audit import compare_calories, source_nutrition_for_audit


class CalorieAuditTest(unittest.TestCase):
    def test_basic_formula_and_source_are_preserved(self):
        values = {'carbs': 10, 'protein': 5, 'fat': 2, 'fiber': None, 'energy_kcal': 78}
        original = copy.deepcopy(values)
        result = compare_calories({}, values)
        self.assertEqual(result['basic_4_4_9_kcal'], 78)
        self.assertEqual(result['status'], 'close_match')
        self.assertTrue(result['fiber_unreported'])
        self.assertEqual(values, original)

    def test_unknown_convention_tests_both_scenarios_without_assigning_one(self):
        values = {'carbs': 80, 'protein': 0, 'fat': 0, 'fiber': 70, 'energy_kcal': 180}
        result = compare_calories({}, values)
        self.assertEqual(result['status'], 'close_match')
        self.assertEqual(result['carbs_label_mode'], 'unknown')
        self.assertEqual(len(result['scenarios']), 2)

    def test_eu_and_non_eu_fiber_are_counted_differently(self):
        values = {'carbs': 10, 'protein': 0, 'fat': 0, 'fiber': 5, 'energy_kcal': 50}
        self.assertEqual(compare_calories({'carbs_label_mode': 'eu'}, values)['status'], 'close_match')
        self.assertEqual(compare_calories({'carbs_label_mode': 'non_eu'}, values)['status'], 'discrepancy')

    def test_missing_carbs_are_not_reconstructed_from_calories(self):
        values = {'carbs': None, 'protein': 0, 'fat': 0, 'energy_kcal': 9.2}
        result = compare_calories({}, values)
        self.assertEqual(result['status'], 'incomplete_or_invalid_macros')
        self.assertNotIn('basic_4_4_9_kcal', result)

    def test_zero_calories_do_not_cause_division_by_zero(self):
        result = compare_calories({}, {'carbs': 0, 'protein': 0, 'fat': 0, 'energy_kcal': 0})
        self.assertEqual(result['status'], 'close_match')
        self.assertIsNone(result['relative_delta_percent'])

    def test_suspicious_yogurt_calories_are_detected(self):
        result = compare_calories({}, {'carbs': 5.3, 'protein': 4.2, 'fat': 3, 'energy_kcal': 273})
        self.assertEqual(result['status'], 'discrepancy')
        self.assertAlmostEqual(result['basic_4_4_9_kcal'], 65)

    def test_sweeteners_are_flagged_without_replacing_declared_energy(self):
        result = compare_calories({'name': 'Ksylitol'}, {'carbs': 100, 'protein': 0, 'fat': 0, 'energy_kcal': 242})
        self.assertTrue(result['possible_polyol_product'])
        self.assertEqual(result['declared_kcal'], 242)
        self.assertEqual(result['status'], 'discrepancy')

    def test_non_eu_fiber_cannot_exceed_total_carbs(self):
        result = compare_calories({'carbs_label_mode': 'non_eu'}, {'carbs': 2, 'protein': 0, 'fat': 0, 'fiber': 3, 'energy_kcal': 10})
        self.assertEqual(result['status'], 'invalid_fiber_total_carbs_relation')

    def test_source_missing_macros_are_not_replaced_by_working_zeros(self):
        source = {'carbs': 100, 'fat': None, 'protein': None, 'energy_kcal': 400}
        working = dict(source, fat=0, protein=0)
        values = source_nutrition_for_audit({'nutrition_as_exported': source}, working)
        self.assertEqual(compare_calories({}, values)['status'], 'incomplete_or_invalid_macros')
        self.assertEqual(compare_calories({}, working)['status'], 'close_match')
        self.assertIsNone(source['fat'])


if __name__ == '__main__':
    unittest.main()
