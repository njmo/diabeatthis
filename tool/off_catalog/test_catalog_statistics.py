"""Statistics distinguish completeness, physical basis and import approval."""

import unittest

from common.catalog_partition import classify
from common.catalog_statistics import summarize, package_unit_hint


def row(identity='maker_1', unit='g', name='Jogurt'):
    record = {'id': identity, 'manufacturer': 'maker', 'name': name, 'source_url': 'https://example.com/' + identity,
              'basis': {'amount': 100, 'unit': unit}, 'preparation': 'as_sold', 'carbs_label_mode': 'unknown',
              'nutrition': {'carbs': 5, 'fat': 3, 'protein': 4, 'fiber': None, 'energy_kcal': 63}}
    return {'id': identity, 'record': record, 'classification': classify(record, manufacturer=True, source_verified=True)}


class CatalogStatisticsTest(unittest.TestCase):
    def test_complete_grams_do_not_imply_import_approval_or_require_fiber(self):
        report = summarize([row()])
        self.assertEqual(report['sources']['maker']['core_valid_individually'], 1)
        self.assertEqual(report['sources']['maker']['core_valid_without_fiber'], 1)
        self.assertEqual(report['nutrition_basis'], {'g': 1})
        self.assertEqual(report['totals']['import_ready'], 0)

    def test_ml_scenario_excludes_suspect_candy_label(self):
        report = summarize([row(), row('maker_2', 'ml', 'Mleko'), row('maker_3', 'ml', 'Cukierki krówka')])
        self.assertEqual(report['ml_support_scenario']['ml_only_partition_blocker'], 2)
        self.assertEqual(report['ml_support_scenario']['additional_candidates_with_ml_support'], 1)
        self.assertEqual(report['ml_support_scenario']['candidates_after_ml_support'], 2)

    def test_duplicate_source_identity_is_not_double_counted(self):
        with self.assertRaises(ValueError):
            summarize([row(), row()])

    def test_package_ml_is_not_a_nutrition_basis(self):
        value = row()
        value['record']['quantity'] = '500 ml'
        self.assertEqual(package_unit_hint(value['record']), 'ml')
        report = summarize([value])
        self.assertEqual(report['nutrition_basis'], {'g': 1})
        self.assertEqual(report['packaging_unit_hints_not_nutrition_basis']['maker']['ml'], 1)

    def test_missing_and_invalid_fields_have_different_statistics(self):
        missing, invalid = row(), row('maker_2')
        missing['classification']['nutrition']['protein'] = None
        invalid['classification']['nutrition']['protein'] = 150
        report = summarize([missing, invalid])
        self.assertEqual(report['missing_core_patterns']['protein'], 1)
        self.assertEqual(report['missing_core_patterns']['none'], 1)
        self.assertEqual(report['sources']['maker']['core_present'], 1)
        self.assertEqual(report['sources']['maker']['core_valid_individually'], 0)


if __name__ == '__main__':
    unittest.main()
