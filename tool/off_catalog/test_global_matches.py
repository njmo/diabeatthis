import csv
import gzip
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from match_global_off import scan
from compile_final_audit import valid_profile


class GlobalMatchTest(unittest.TestCase):
    def test_global_name_matching_keeps_unknown_basis_and_conflicting_profiles_separate(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);catalog=root/'local.sqlite'
            target={'id':'off_1','source_id':'1','name':'Jogurt naturalny','brand':'Maker',
                    'nutrition_as_exported':{'carbs':None,'fat':None,'protein':None},'macro_audit':{'record_kind':'food_or_unclassified'}}
            with sqlite3.connect(catalog) as db:
                db.execute('CREATE TABLE products(document TEXT)');db.execute('INSERT INTO products VALUES (?)',(json.dumps(target),))
            rows=[{'code':'2','product_name':'Jogurt naturalny','brands':'Maker','carbohydrates_100g':'4','fat_100g':'2','proteins_100g':'5','fiber_100g':''},
                  {'code':'3','product_name':'Jogurt naturalny','brands':'Maker','carbohydrates_100g':'8','fat_100g':'2','proteins_100g':'5','fiber_100g':''},
                  {'code':'4','product_name':'Jogurt naturalny','brands':'Other','carbohydrates_100g':'4','fat_100g':'2','proteins_100g':'5','fiber_100g':''}]
            archive=root/'world.gz'
            with gzip.open(archive,'wt',newline='') as stream:
                writer=csv.DictWriter(stream,fieldnames=list(rows[0]),delimiter='\t');writer.writeheader();writer.writerows(rows)
            report=scan(archive,catalog,root/'out')
            result=json.loads((root/'out/candidates.jsonl').read_text())
            self.assertEqual(result['status'],'conflicting_reference_profiles')
            self.assertEqual(len(result['candidates']),2)
            self.assertTrue(all(r['basis']=='unknown_100g_or_100ml' for r in result['candidates']))
            self.assertTrue(all(r['nutrition']['fiber'] is None for r in result['candidates']))
            self.assertEqual(report['counts']['world_rows_scanned'],3)
            with sqlite3.connect(catalog) as db:self.assertEqual(json.loads(db.execute('select document from products').fetchone()[0]),target)

    def test_source_profile_requires_only_core_macros_but_explicit_basis(self):
        source={'url':'https://maker.example/product','basis':{'amount':100,'unit':'g'},'nutrition':{'carbs':0,'fat':0,'protein':0,'fiber':None,'energy_kcal':None},'preparation':'as_sold'}
        self.assertIsNotNone(valid_profile(source))
        source['basis']=None
        self.assertIsNone(valid_profile(source))


if __name__=='__main__':unittest.main()
