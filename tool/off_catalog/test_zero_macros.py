import copy
import unittest
from common.type_zero_macros import apply_type_zeros
from common.source_zero_macros import apply_source_zeros
from common.macro_audit import assess_record
from common.nutrition_facts import working_nutrition
from common.zero_normalization import normalize_zeros


def record(name='Olej rzepakowy',**values):
    return {'id':'off_123','name':name,'brand':'Maker','nutrition_as_exported':{'carbs':None,'fat':100,'protein':None,'fiber':None,'energy_kcal':900,**values},'review_flags':[]}


class TypeZeroTest(unittest.TestCase):
    def test_oil_missing_carbs_protein_becomes_working_zero_with_provenance(self):
        original=record();before=copy.deepcopy(original)
        result=apply_type_zeros(original)
        self.assertEqual(working_nutrition(result)['carbs'],0)
        self.assertEqual(working_nutrition(result)['protein'],0)
        self.assertEqual(working_nutrition(result)['fat'],100)
        self.assertIsNone(result['nutrition_as_exported']['carbs'])
        self.assertIsNone(working_nutrition(result)['fiber'])
        self.assertEqual(result['nutrition_imputations']['carbs']['method'],'type_based_zero_imputation')
        self.assertEqual(assess_record(result)['status'],'complete_core_macros')
        self.assertEqual(original,before)

    def test_known_value_is_preserved_and_conflict_is_visible(self):
        result=apply_type_zeros(record(name='Coconut oil virgin',carbs=0.6))
        self.assertEqual(working_nutrition(result)['carbs'],0.6)
        self.assertEqual(working_nutrition(result)['protein'],0)
        self.assertIn('existing_carbs_contradicts_pure_oil',result['zero_fill_review_flags'])
        self.assertEqual(assess_record(result)['route'],'zero_fill_inference_review')

    def test_suspicious_oil_fat_is_never_scaled_or_hidden(self):
        result=apply_type_zeros(record(name='Olej z ostropestu',fat=10,energy_kcal=90))
        self.assertEqual(working_nutrition(result)['fat'],10)
        self.assertIn('oil_fat_basis_or_identity_requires_review',result['zero_fill_review_flags'])

    def test_sugar_only_fills_fat_and_protein_not_missing_carbs(self):
        result=apply_type_zeros(record(name='White sugar',carbs=100,fat=None))
        self.assertEqual(working_nutrition(result)['fat'],0)
        self.assertEqual(working_nutrition(result)['protein'],0)
        missing=apply_type_zeros(record(name='Cukier Puder',carbs=None,fat=0,protein=0))
        self.assertIsNone(working_nutrition(missing)['carbs'])

    def test_oil_in_food_or_aroma_does_not_make_food_a_pure_oil(self):
        for name in ['Makrela w oleju','Szprot w oleju','Zielone oliwki','Orange oil','Olej rzepakowy z masłem','Olej smakowy z czosnkiem','Masło']:
            result=apply_type_zeros(record(name=name))
            self.assertNotIn('nutrition_working',result,name)

    def test_flavored_water_and_sugar_free_claims_do_not_prove_zero(self):
        for name in ['Woda + witaminy','Vitamin water','Zero Sugar Syrup','Fat Killer vitaminwater','Sugar free lemon jelly','Mleko']:
            result=apply_type_zeros(record(name=name,carbs=3,fat=None))
            self.assertNotIn('nutrition_working',result,name)

    def test_no_primary_macro_is_invented_when_all_three_are_missing(self):
        result=apply_type_zeros(record(carbs=None,fat=None,protein=None))
        self.assertNotIn('nutrition_working',result)

    def test_invalid_source_is_not_treated_like_absent_data(self):
        original=record();original['source_review_flags']=['invalid_carbs']
        result=apply_type_zeros(original)
        self.assertIsNone(working_nutrition(result)['carbs'])
        self.assertEqual(working_nutrition(result)['protein'],0)

    def test_normalization_is_idempotent(self):
        once=apply_type_zeros(record())
        self.assertEqual(apply_type_zeros(once),once)

    def test_zero_from_explicit_label_is_used_without_changing_nonzero_fields(self):
        original=record(name='Sprite',carbs=4,fat=None)
        profile={'source_url':'https://maker.example/sprite','preparation':'as_sold','nutrition':{'carbs':4,'fat':0,'protein':0}}
        result=apply_source_zeros(original,[profile])
        self.assertEqual(working_nutrition(result)['fat'],0)
        self.assertEqual(working_nutrition(result)['protein'],0)
        self.assertEqual(working_nutrition(result)['carbs'],4)
        self.assertEqual(result['nutrition_imputations']['fat']['method'],'source_reported_zero')
        self.assertFalse(result.get('zero_fill_review_flags'))

    def test_later_reported_source_value_wins_over_old_zero_and_cached_values(self):
        result=apply_type_zeros(record())
        result['nutrition_as_exported']['protein']=0.4
        self.assertEqual(working_nutrition(result)['protein'],0.4)
        self.assertEqual(working_nutrition(result)['carbs'],0)

    def test_type_audit_still_runs_when_sources_fill_last_missing_fields(self):
        original=record(name='Woda mineralna',carbs=10,fat=None,protein=None)
        source={'source_url':'https://maker.example/water','preparation':'as_sold','nutrition':{'carbs':10,'fat':0,'protein':0}}
        result=normalize_zeros(original,[source])
        self.assertEqual(working_nutrition(result)['protein'],0)
        self.assertIn('existing_carbs_contradicts_plain_water',result['zero_fill_review_flags'])

    def test_nonzero_source_evidence_blocks_generic_zero_for_same_field(self):
        original=record(carbs=None,protein=0)
        source={'source_url':'https://maker.example/oil','preparation':'as_sold','nutrition':{'carbs':1,'fat':100,'protein':0}}
        result=normalize_zeros(original,[source])
        self.assertIsNone(working_nutrition(result)['carbs'])
        self.assertIn('nonzero_source_prevents_type_zero_carbs',result['zero_fill_review_flags'])

    def test_later_conflicting_source_marks_existing_inferred_zero_for_review(self):
        original=apply_type_zeros(record())
        source={'source_url':'https://maker.example/oil','preparation':'as_sold','nutrition':{'carbs':1,'fat':100,'protein':0}}
        result=normalize_zeros(original,[source])
        self.assertIn('source_carbs_differs_from_existing',result['zero_fill_review_flags'])
        self.assertEqual(assess_record(result)['route'],'zero_fill_inference_review')

    def test_sources_disagreeing_on_zero_do_not_force_zero(self):
        a={'source_url':'https://maker.example/a','preparation':'as_sold','nutrition':{'fat':0}}
        b={'source_url':'https://maker.example/b','preparation':'as_sold','nutrition':{'fat':0.2}}
        result=apply_source_zeros(record(fat=None,carbs=3),[a,b])
        self.assertIsNone(working_nutrition(result)['fat'])


if __name__=='__main__':unittest.main()
