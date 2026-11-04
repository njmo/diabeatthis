import copy
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from common.macro_audit import assess_record
from clean_working_catalog import clean


def record(name='Jogurt naturalny', **macros):
    return {'id':'off_123','source_id':'123','name':name,'brand':'Producer','quantity':'200 g',
            'nutrition_as_exported':{'carbs':4,'fat':2,'protein':5,'fiber':None,'energy_kcal':None,**macros},
            'review_flags':['missing_fiber','missing_energy_kcal','nutrition_basis_unresolved']}


class MacroAuditTest(unittest.TestCase):
    def test_fiber_and_energy_are_optional(self):
        result=assess_record(record())
        self.assertEqual(result['status'],'complete_core_macros')
        self.assertFalse(result['fiber_required'])
        self.assertEqual(result['missing_core_fields'],[])

    def test_zero_is_a_valid_reported_core_value(self):
        self.assertEqual(assess_record(record(carbs=0,fat=0,protein=0))['status'],'complete_core_macros')

    def test_missing_fields_are_reported_precisely_and_never_inferred_zero(self):
        for missing in [('carbs',),('fat',),('protein',),('carbs','fat'),('carbs','protein'),('fat','protein'),('carbs','fat','protein')]:
            result=assess_record(record(**dict.fromkeys(missing)))
            self.assertEqual(set(result['missing_core_fields']),set(missing))
            self.assertEqual(result['status'],'missing_core_macros')

    def test_range_review_is_not_confused_with_absence(self):
        result=assess_record(record(carbs=110))
        self.assertEqual(result['status'],'range_review')
        self.assertEqual(result['missing_core_fields'],[])

    def test_non_food_is_routed_away_from_human_nutrition(self):
        self.assertEqual(assess_record(record(name='Farba antykorozyjna'))['route'],'excluded_from_human_food_catalog')

    def test_cleanup_removes_unnamed_from_database_export_and_search(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'original';source.mkdir()
            rows=[record(),record(name='  ')];rows[1].update(id='off_456',source_id='456')
            with sqlite3.connect(source/'catalog.sqlite') as db:
                db.execute('CREATE TABLE products (code TEXT, document TEXT)')
                for r in rows:db.execute('INSERT INTO products VALUES (?,?)',(r['source_id'],json.dumps(r)))
            (source/'manifest.json').write_text(json.dumps({'counts':{'source_rows':2,'poland_products':2,'products_with_core_macros':2}}))
            report=clean(source,root/'working')
            self.assertEqual(report['counts']['removed_without_name'],1)
            self.assertEqual(report['core_complete_without_fiber'],1)
            output=(root/'working/current').resolve()
            with sqlite3.connect(output/'catalog.sqlite') as db:
                self.assertEqual(db.execute('SELECT count(*) FROM products').fetchone()[0],1)
                self.assertEqual(db.execute('SELECT count(*) FROM product_search').fetchone()[0],1)
            kept=json.loads((output/'products-pl.jsonl').read_text())
            self.assertNotIn('missing_fiber',kept['review_flags'])
            self.assertIn('missing_fiber',kept['source_review_flags'])
            self.assertIsNone(kept['nutrition_as_exported']['fiber'])
            self.assertEqual(kept['macro_audit']['status'],'complete_core_macros')
            with sqlite3.connect(source/'catalog.sqlite') as db:
                self.assertEqual(db.execute('SELECT count(*) FROM products').fetchone()[0],2)
            repeated=clean(root/'working/current',root/'working')
            self.assertEqual(repeated['counts']['removed_without_name'],0)
            self.assertEqual(repeated['removed_without_name_total'],1)
            self.assertEqual(repeated['counts']['named_records'],1)


if __name__=='__main__': unittest.main()
