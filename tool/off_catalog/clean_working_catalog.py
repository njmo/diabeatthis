#!/usr/bin/env python3
"""Publish a named-only working generation and classify every required macro gap."""

import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sqlite3
import uuid

from common.macro_audit import assess_record
from common.products import search_text
from common.nutrition_facts import working_nutrition

ROOT = Path(__file__).resolve().parent


def clean(source, destination, transform=None):
    original = source.resolve(strict=True)
    source_manifest = json.loads((original / 'manifest.json').read_text())
    generation = 'named-core-' + uuid.uuid4().hex[:16]
    parent = destination / 'generations'
    parent.mkdir(parents=True, exist_ok=True)
    output = parent / (generation + '.partial')
    output.mkdir()
    counts, patterns, routes, flags = Counter(), Counter(), Counter(), Counter()
    optional_fiber = 0
    manufacturers = defaultdict(Counter)
    with sqlite3.connect(f'file:{original / "catalog.sqlite"}?mode=ro', uri=True) as read, sqlite3.connect(output / 'catalog.sqlite') as db:
        db.execute('CREATE TABLE products (id TEXT PRIMARY KEY, code TEXT UNIQUE, name TEXT, brand TEXT, document TEXT NOT NULL)')
        db.execute("CREATE VIRTUAL TABLE product_search USING fts5(id UNINDEXED, text, tokenize='unicode61 remove_diacritics 2')")
        with (output / 'products-pl.jsonl').open('w', encoding='utf-8') as lines, (output / 'macro_gaps.jsonl').open('w', encoding='utf-8') as gaps, (output / 'review.csv').open('w', newline='', encoding='utf-8') as review:
            writer = csv.writer(review)
            writer.writerow(['id','name','brand','carbs','fat','protein','fiber_optional','macro_status','missing_core','record_kind','route'])
            for (payload,) in read.execute('SELECT document FROM products ORDER BY code'):
                record = json.loads(payload)
                counts['input_records'] += 1
                if not record.get('name', '').strip():
                    counts['removed_without_name'] += 1
                    continue
                if transform is not None:
                    record=transform(record)
                if record.get('nutrition_imputations'):
                    record['nutrition_working']=working_nutrition(record)
                audit = assess_record(record)
                record['macro_audit'] = audit
                record.setdefault('source_review_flags', record.get('review_flags', []))
                record['review_flags'] = [f for f in record.get('review_flags', []) if f not in ('missing_fiber', 'missing_energy_kcal')]
                counts['named_records'] += 1
                counts[audit['status']] += 1
                counts[audit['record_kind']] += 1
                routes[audit['route']] += 1
                if audit['missing_core_fields']:
                    patterns[audit['missing_pattern']] += 1
                    manufacturers[record.get('brand') or '(unreported)'][audit['missing_pattern']] += 1
                    gaps.write(json.dumps(record, ensure_ascii=False, allow_nan=False) + '\n')
                if audit['status'] == 'complete_core_macros' and not audit['fiber_reported']:
                    optional_fiber += 1
                flags.update(record['review_flags'])
                value = json.dumps(record, ensure_ascii=False, allow_nan=False, separators=(',', ':'))
                lines.write(value + '\n')
                db.execute('INSERT INTO products VALUES (?,?,?,?,?)',(record['id'],record['source_id'],record['name'],record['brand'],value))
                db.execute('INSERT INTO product_search VALUES (?,?)',(record['id'],search_text(record['name']+' '+record['brand'])))
                safe = lambda s: "'" + s if s.startswith(('=','+','-','@','\t','\r')) else s
                n=working_nutrition(record)
                writer.writerow([record['id'],safe(record['name']),safe(record['brand']),n.get('carbs'),n.get('fat'),n.get('protein'),n.get('fiber'),audit['status'],';'.join(audit['missing_core_fields']),audit['record_kind'],audit['route']])
        db.commit()
        assert db.execute('SELECT count(*) FROM products').fetchone()[0] == counts['named_records']
        assert db.execute('SELECT count(*) FROM products WHERE trim(name)=""').fetchone()[0] == 0
        assert db.execute('SELECT count(*) FROM product_search').fetchone()[0] == counts['named_records']
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    counts.setdefault('removed_without_name',0)
    removed_total=source_manifest['counts'].get('removed_without_name',0)+counts['removed_without_name']
    report = {'removed_without_name_total':removed_total,'created_at': datetime.now(timezone.utc).isoformat(), 'source_generation': original.name,
              'counts':dict(counts),'missing_patterns':dict(patterns),'routes':dict(routes),
              'core_complete_without_fiber':optional_fiber,'required_macros':['carbs','fat','protein'],
              'optional_fields':['fiber','energy_kcal'],'firebase_writes':0,
              'manufacturers_with_missing_core':{k:dict(v) for k,v in sorted(manufacturers.items())},
              'coverage':'Every named record classified; a classification is not a claim of web research or nutrition verification.'}
    (output / 'macro_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    manifest = dict(source_manifest)
    manifest.update(working_dataset=True,source_generation=original.name,review_flags=dict(flags),required_macros=['carbs','fat','protein'],optional_fields=['fiber','energy_kcal'])
    manifest['counts']=dict(source_manifest['counts'])
    manifest['counts']['poland_products']=counts['named_records']
    manifest['counts']['removed_without_name']=source_manifest['counts'].get('removed_without_name',0)+counts['removed_without_name']
    manifest['counts']['products_with_core_macros']=counts['complete_core_macros']+counts['range_review']
    (output / 'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    (output / 'cleanup_provenance.json').write_text(json.dumps({'source_generation':str(original),'raw_archive_preserved':True,'removed_count':counts['removed_without_name'],'reason':'User requested removal of unnamed working records.'},indent=2)+'\n')
    final = parent / generation
    output.rename(final)
    pointer=destination/('.current-'+uuid.uuid4().hex)
    pointer.symlink_to(Path('generations')/generation,target_is_directory=True)
    os.replace(pointer,destination/'current')
    print(json.dumps({k:v for k,v in report.items() if k!='manufacturers_with_missing_core'},ensure_ascii=False,indent=2))
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT/'data/poland/current')
    parser.add_argument('--destination',type=Path,default=ROOT/'data/poland')
    args=parser.parse_args();clean(args.source,args.destination)
