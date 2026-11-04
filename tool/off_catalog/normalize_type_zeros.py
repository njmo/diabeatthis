#!/usr/bin/env python3
"""Publish an auditable working generation with sensible commodity-specific zeros."""

import argparse
from collections import Counter
import csv
import json
from pathlib import Path
import sqlite3
from clean_working_catalog import clean
from common.type_zero_macros import apply_type_zeros
from common.source_zero_macros import apply_source_zeros
from common.zero_normalization import normalize_zeros

ROOT=Path(__file__).resolve().parent


def normalize(source,destination):
    changes=[]
    source_file=ROOT/'data/final_audit/all_named_records.jsonl'
    evidence={}
    if source_file.exists():
        for line in source_file.open(encoding='utf-8'):
            row=json.loads(line)
            if row.get('source_profiles'):evidence[row['record']['id']]=row['source_profiles']
    def transform(record):
        result=normalize_zeros(record,evidence.get(record['id'],[]))
        before=record.get('nutrition_imputations',{})
        added={k:v for k,v in result.get('nutrition_imputations',{}).items() if k not in before}
        if added:changes.append({'id':result['id'],'name':result['name'],'filled_fields':list(added),'provenance':added,'review_flags':result.get('zero_fill_review_flags',[])})
        return result
    clean(source,destination,transform=transform)
    report={'records_changed':len(changes),'fields_filled':sum(len(r['filled_fields']) for r in changes),
            'by_field':dict(Counter(k for r in changes for k in r['filled_fields'])),
            'by_method':dict(Counter(p['method'] for r in changes for p in r['provenance'].values())),
            'records_requiring_review':sum(bool(r['review_flags']) for r in changes),
            'records':changes,'source_facts_overwritten':False,'firebase_writes':0}
    with sqlite3.connect(destination/'current/catalog.sqlite') as db:
        records=[json.loads(row[0]) for row in db.execute('SELECT document FROM products')]
    report['cumulative_records']=[{'id':r['id'],'name':r['name'],'provenance':r['nutrition_imputations'],'review_flags':r.get('zero_fill_review_flags',[])} for r in records if r.get('nutrition_imputations')]
    report['total_records_with_imputations']=sum(bool(r.get('nutrition_imputations')) for r in records)
    report['total_records_requiring_review']=sum(bool(r.get('zero_fill_review_flags')) for r in records if r.get('nutrition_imputations'))
    report['total_complete_after_zero_fill']=sum(not r['macro_audit']['missing_core_fields'] for r in records if r.get('nutrition_imputations'))
    report['total_complete_without_review']=sum(not r['macro_audit']['missing_core_fields'] and not r.get('zero_fill_review_flags') for r in records if r.get('nutrition_imputations'))
    report['total_fields_imputed']=sum(len(r.get('nutrition_imputations',{})) for r in records)
    (destination/'current/type_zero_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('records','cumulative_records')},ensure_ascii=False,indent=2))
    return report


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,default=ROOT/'data/poland/current')
    p.add_argument('--destination',type=Path,default=ROOT/'data/poland')
    a=p.parse_args();normalize(a.source,a.destination)
