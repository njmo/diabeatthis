#!/usr/bin/env python3
"""Audit every local OFF/manufacturer record into exactly two review buckets."""

from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import os
import tempfile

from common.catalog_partition import classify

ROOT = Path(__file__).resolve().parent


def read_rows(path):
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def main():
    generation = (ROOT / 'data/poland/current').resolve(strict=True)
    inputs = [generation / 'products-pl.jsonl'] + sorted((ROOT / 'data/bulk').glob('*/catalog.jsonl'))
    records = []
    hashes = {}
    for path in inputs:
        hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
        for row in read_rows(path):
            records.append((row, path != inputs[0], path.parent))
    identities = [row['id'] for row, _, _ in records]
    if len(identities) != len(set(identities)):
        raise ValueError('Duplicate source IDs: refusing an ambiguous partition')
    names = defaultdict(list)
    for row, manufacturer, _ in records:
        if manufacturer:
            names[(row['manufacturer'], row['name'].strip().casefold())].append(row)
    conflicting = set()
    for rows in names.values():
        complete = [row for row in rows if all(row.get('nutrition', {}).get(key) is not None for key in ('carbs', 'fat', 'protein'))]
        profiles = {json.dumps([row.get('basis'), row.get('nutrition')], sort_keys=True) for row in complete}
        if len(profiles) > 1:
            conflicting.update(row['id'] for row in rows)
    output = ROOT / 'data/partition'
    output.mkdir(exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix='generation-', dir=output))
    counts, reasons, source_counts, blockers = Counter(), Counter(), Counter(), Counter()
    snapshot_verified = 0
    with (destination / 'consistent_candidates.jsonl').open('w') as accepted, (destination / 'requires_review.jsonl').open('w') as rejected:
        for row, manufacturer, parent in records:
            verified = False
            if manufacturer:
                key = hashlib.sha256(row['source_url'].encode()).hexdigest()
                body = parent / 'cache' / (key + '.body')
                verified = body.exists() and hashlib.sha256(body.read_bytes()).hexdigest() == row.get('source_sha256')
                snapshot_verified += verified
            result = classify(row, manufacturer=manufacturer, conflicting_name=row['id'] in conflicting, source_verified=verified)
            counts[result['group']] += 1
            source_counts[f"{row.get('manufacturer', 'off')}:{result['group']}"] += 1
            reasons.update(result['review_reasons'])
            blockers.update(result['import_blockers'])
            payload = {'id': row['id'], 'record': row, 'classification': result}
            stream = accepted if result['group'] == 'consistent_candidates' else rejected
            stream.write(json.dumps(payload, ensure_ascii=False, allow_nan=False) + '\n')
    report = {
        'input_records': len(records), 'unique_source_ids': len(set(identities)), 'counts': dict(counts),
        'source_counts': dict(source_counts), 'review_reason_counts': dict(reasons), 'import_blocker_counts': dict(blockers),
        'verified_manufacturer_snapshots': snapshot_verified, 'ambiguous_name_records': len(conflicting),
        'input_sha256': hashes, 'firebase_writes': 0,
        'notes': ['Exactly one bucket per source identity; OFF and manufacturer identities are not deduplicated by name.',
                  'Consistent candidates are not publication approval. Check import_ready and import_blockers.',
                  'No 100ml-to-100g conversion, invented fiber, or EU/US convention assignment.'],
    }
    (destination / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    temporary = output / '.current-next'
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(destination.name)
    os.replace(temporary, output / 'current')
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
