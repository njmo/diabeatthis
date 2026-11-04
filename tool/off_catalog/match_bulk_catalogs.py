#!/usr/bin/env python3
"""Match whole catalogs locally; write only enrichment proposals and exception batches."""

import argparse
from collections import Counter
import json
import hashlib
from pathlib import Path
import sqlite3

from common.catalog_matching import match_product, manufacturer_matches
from common.nutrition_facts import working_nutrition

ROOT = Path(__file__).resolve().parent


def match(catalog, sources, output, batch_size=100):
    output.mkdir(parents=True, exist_ok=True)
    products = []
    manifests = {}
    for source in sources:
        manifest = json.loads((source / 'manifest.json').read_text())
        if not manifest.get('complete'):
            raise ValueError('Incomplete manufacturer catalog cannot establish unique matches: ' + str(source))
        raw = (source / 'catalog.jsonl').read_bytes()
        if manifest.get('catalog_sha256') != hashlib.sha256(raw).hexdigest():
            raise ValueError('Catalog and manifest snapshot mismatch: ' + str(source))
        products.extend(json.loads(line) for line in raw.decode('utf-8').splitlines())
        manifests[source.name] = manifest
    by_manufacturer = {p['manufacturer'] for p in products}
    counts, methods = Counter(), Counter()
    exceptions, proposals = [], []
    with sqlite3.connect(f'file:{catalog.resolve()}?mode=ro', uri=True) as db:
        for (payload,) in db.execute('SELECT document FROM products ORDER BY code'):
            original = json.loads(payload)
            if not original['name'] or (all(working_nutrition(original).get(k) is not None for k in ('carbs', 'fat', 'protein')) and not original.get('zero_fill_review_flags')):
                continue
            if not any(manufacturer_matches(original, source) for source in by_manufacturer):
                counts['outside_configured_manufacturers'] += 1
                continue
            result = match_product(original, products)
            result['target_id'], result['original_name'], result['brand'] = original['id'], original['name'], original['brand']
            counts[result['status']] += 1
            if result['status'] == 'source_backed_proposal':
                proposals.append(result)
                methods[result['match_method']] += 1
            else:
                candidates = [p for p in products if p['id'] in result['candidates']]
                exceptions.append({'original': original, 'reason': result['reason'], 'catalog_candidates': candidates})
    for filename, rows in [('proposals.jsonl', proposals), ('exceptions.jsonl', exceptions)]:
        temporary = output / (filename + '.partial')
        with temporary.open('w', encoding='utf-8') as stream:
            for row in rows:
                stream.write(json.dumps(row, ensure_ascii=False, allow_nan=False) + '\n')
        temporary.replace(output / filename)
    batches = output / 'exception_batches'
    batches.mkdir(exist_ok=True)
    active_batches = set()
    for index in range(0, len(exceptions), batch_size):
        active_batches.add(f'batch_{index // batch_size + 1:04}.json')
        (batches / f'batch_{index // batch_size + 1:04}.json').write_text(json.dumps({'records': exceptions[index:index+batch_size]}, ensure_ascii=False, indent=2) + '\n')
    for old in batches.glob('batch_*.json'):
        if old.name not in active_batches:
            old.unlink()
    manifest = {'source_products': len(products), 'statuses': dict(counts), 'match_methods': dict(methods),
                'manufacturer_catalogs': manifests, 'exception_batches': (len(exceptions)+batch_size-1)//batch_size,
                'firebase_writes': 0, 'barcode_required': False, 'publication_approved': False}
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k:v for k,v in manifest.items() if k != 'manufacturer_catalogs'}, ensure_ascii=False, indent=2))
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', type=Path, default=ROOT / 'data/poland/current/catalog.sqlite')
    parser.add_argument('--sources', nargs='+', type=Path, default=[ROOT / 'data/bulk/mlekovita', ROOT / 'data/bulk/piatnica'])
    parser.add_argument('--output', type=Path, default=ROOT / 'data/bulk_matches')
    parser.add_argument('--batch-size', type=int, default=100)
    args = parser.parse_args()
    if args.batch_size < 1:
        parser.error('Batch size must be positive')
    match(args.catalog, args.sources, args.output, args.batch_size)
