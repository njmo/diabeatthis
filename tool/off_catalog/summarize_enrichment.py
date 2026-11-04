#!/usr/bin/env python3
"""Collect researched batches into a validated, source-preserving proposal ledger."""

import argparse
from collections import Counter
import csv
from datetime import datetime, timezone
import json
from pathlib import Path
import sqlite3

from common.enrichment import validate_proposal

ROOT = Path(__file__).resolve().parent


def summarize(batch_directory, catalog, output):
    output.mkdir(parents=True, exist_ok=True)
    statuses, brands, errors = Counter(), Counter(), Counter()
    rows, pending, seen = [], [], set()
    with sqlite3.connect(f"file:{catalog.resolve()}?mode=ro", uri=True) as db:
        for input_file in sorted(batch_directory.glob('batch_*_input.json')):
            batch = json.loads(input_file.read_text())
            result_file = input_file.with_name(input_file.name.replace('_input.json', '_result.json'))
            if not result_file.exists():
                pending.append(batch['batch_id'])
                continue
            result = json.loads(result_file.read_text())
            if result.get('batch_id') != batch['batch_id']:
                raise ValueError('Batch identity mismatch: ' + str(result_file))
            expected = {r['source_id']: r for r in batch['records']}
            researched = result['records']
            if len(researched) != len(expected) or {r['code'] for r in researched} != set(expected):
                raise ValueError('Incomplete or unexpected batch identities: ' + str(result_file))
            for record in researched:
                code = record['code']
                if code in seen:
                    raise ValueError('Duplicate researched code: ' + code)
                seen.add(code)
                original_row = db.execute('SELECT document FROM products WHERE code=?', (code,)).fetchone()
                if original_row is None:
                    raise ValueError('Product not present in source snapshot: ' + code)
                original = json.loads(original_row[0])
                validation = validate_proposal(record, original)
                statuses.update([validation['status']])
                errors.update(validation['errors'])
                brands.update([original['brand']])
                rows.append({'code': code, 'batch_id': batch['batch_id'], 'original_name': original['name'],
                             'brand': original['brand'], 'proposed_name': record['name'],
                             'research': record, 'validation': validation,
                             'source_snapshot_nutrition': original['nutrition_as_exported']})
    manifest = {'schema_version': 1, 'created_at': datetime.now(timezone.utc).isoformat(),
                'assigned_products': len(rows), 'reviewed_products': len(rows) - statuses.get('deferred', 0), 'statuses': dict(statuses), 'brands': dict(brands),
                'validation_errors': dict(errors), 'pending_batches': pending,
                'firebase_writes': 0, 'firebase_gemini_api_calls': 0, 'publication_approved': False,
                'notes': ['Source facts remain unchanged. Patches are proposals for missing fields only.',
                          'Source evidence and barcode matching require review before accepting a proposal.',
                          'Unknown fiber and carbohydrate conventions are not inferred.',
                          'Manufacturer/retailer reuse rights are not established by a public URL.']}
    ledger = output / 'proposals.jsonl.partial'
    with ledger.open('w') as stream:
        for row in sorted(rows, key=lambda r: r['code']):
            stream.write(json.dumps(row, ensure_ascii=False, allow_nan=False) + '\n')
    ledger.replace(output / 'proposals.jsonl')
    with (output / 'review.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.writer(stream)
        writer.writerow(['code', 'original_name', 'proposed_name', 'brand', 'status', 'basis',
                         'proposed_carbs', 'proposed_fiber', 'proposed_fat', 'proposed_protein', 'proposed_energy_kcal', 'errors', 'source_urls'])
        def safe(value):
            text = str(value)
            return "'" + text if text.startswith(('=', '+', '-', '@', '\t', '\r')) else text
        for row in sorted(rows, key=lambda r: r['code']):
            validation = row['validation']
            patch = validation['patch']
            writer.writerow([row['code'], safe(row['original_name']), safe(row['proposed_name']), safe(row['brand']),
                             validation['status'], json.dumps(validation.get('nutrition_basis')),
                             *(patch.get(key) for key in ('carbs', 'fiber', 'fat', 'protein', 'energy_kcal')),
                             ';'.join(validation['errors']), ';'.join(s['url'] for s in validation['sources'])])
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batches', type=Path, default=ROOT / 'curation/batches')
    parser.add_argument('--catalog', type=Path, default=ROOT / 'data/poland/current/catalog.sqlite')
    parser.add_argument('--output', type=Path, default=ROOT / 'data/enrichment')
    args = parser.parse_args()
    summarize(args.batches, args.catalog, args.output)
