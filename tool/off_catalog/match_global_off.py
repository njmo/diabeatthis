#!/usr/bin/env python3
"""Scan the already downloaded full OFF export once for exact name/brand candidates."""

import argparse
from collections import Counter, defaultdict
import csv
import gzip
import json
from pathlib import Path
import re
import sqlite3
from common.products import number, search_text, NUTRIENTS
from common.nutrition_facts import working_nutrition

ROOT=Path(__file__).resolve().parent


def identity_name(value):
    value=search_text(value)
    value=re.sub(r'(?<!\w)\d+(?:[.,]\d+)?\s*(?:kg|ml|g|l)\b',' ',value)
    return ' '.join(sorted(re.findall(r'\d+(?:[.,]\d+)?|[^\W\d_]+|%',value.replace(',','.'))))


def brands(value):
    return {search_text(v.strip()) for v in re.split('[,;]',value or '') if v.strip()}


def scan(archive,catalog,output):
    targets=defaultdict(list)
    with sqlite3.connect(f'file:{catalog.resolve()}?mode=ro',uri=True) as db:
        for (payload,) in db.execute('SELECT document FROM products'):
            r=json.loads(payload)
            if r.get('macro_audit',{}).get('record_kind') in ('non_food','pet_food'):continue
            if all(working_nutrition(r).get(k) is not None for k in ('carbs','fat','protein')) and not r.get('zero_fill_review_flags'):continue
            key=identity_name(r['name'])
            if not key:continue
            targets[key].append(r)
    candidates=defaultdict(list);totals=Counter();seen_profiles=defaultdict(set)
    csv.field_size_limit(16*1024*1024)
    with gzip.open(archive,'rt',encoding='utf-8',newline='') as stream:
        reader=csv.DictReader(stream,delimiter='\t')
        for row in reader:
            totals['world_rows_scanned']+=1
            key=identity_name(row.get('product_name') or row.get('generic_name') or '')
            if key not in targets:continue
            values={k:number(row.get(field)) for k,field in NUTRIENTS.items()}
            if any(values[k] is None or values[k]>100 for k in ('carbs','fat','protein')):continue
            code=(row.get('code') or '').strip()
            if not code.isdigit():continue
            source_brands=brands(row.get('brands'))
            for target in targets[key]:
                if code==target['source_id']:continue
                target_brands=brands(target['brand'])
                if target_brands and not (source_brands & target_brands):continue
                # Without a maker, generic single-word names cannot establish identity.
                if not target_brands and len(key.split())<2:continue
                fingerprint=tuple(values[k] for k in ('carbs','fat','protein'))
                seen_profiles[target['id']].add(fingerprint)
                if len(candidates[target['id']])<10:
                    candidates[target['id']].append({'source_id':code,'name':row.get('product_name') or row.get('generic_name'),
                        'brand':row.get('brands'),'quantity':row.get('quantity'),'nutrition':values,
                        'source_url':'https://world.openfoodfacts.org/product/'+code,
                        'countries_tags':row.get('countries_tags'),'basis':'unknown_100g_or_100ml',
                        'carbs_label_mode':'unknown','identity_method':'exact_name_and_brand' if target_brands else 'exact_name_without_manufacturer',
                        'publication_approved':False})
    output.mkdir(parents=True,exist_ok=True)
    statuses=Counter()
    with (output/'candidates.jsonl').open('w',encoding='utf-8') as stream:
        for group in targets.values():
            for target in group:
                choices=candidates[target['id']]
                if not choices:status='no_exact_catalog_candidate'
                elif len(seen_profiles[target['id']])>1:status='conflicting_reference_profiles'
                else:status='candidate_requires_identity_unit_and_convention_review'
                statuses[status]+=1
                stream.write(json.dumps({'target_id':target['id'],'name':target['name'],'brand':target['brand'],
                    'status':status,'distinct_core_profiles':len(seen_profiles[target['id']]),'candidates':choices},ensure_ascii=False)+'\n')
    report={'counts':dict(totals),'target_records':sum(len(r) for r in targets.values()),'statuses':dict(statuses),
            'fiber_required':False,'firebase_writes':0,'ai_api_calls':0,
            'notes':['No values copied into source records. Exact-name candidates are not identity approvals.',
                     'The flat source cannot establish 100g vs 100ml or carbohydrate convention.',
                     'Cross-country product variants may differ; all matches remain proposals.']}
    (output/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return report


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--archive',type=Path,default=ROOT/'data/products.tsv.gz');p.add_argument('--catalog',type=Path,default=ROOT/'data/poland/current/catalog.sqlite');p.add_argument('--output',type=Path,default=ROOT/'data/global_matches');a=p.parse_args();scan(a.archive,a.catalog,a.output)
