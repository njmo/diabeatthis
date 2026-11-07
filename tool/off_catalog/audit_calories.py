#!/usr/bin/env python3
"""Audit every source record, including records for which energy cannot be calculated."""

from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

from common.calorie_audit import compare_calories, source_nutrition_for_audit

ROOT = Path(__file__).resolve().parent


def main():
    generation = (ROOT / 'data/partition/current').resolve(strict=True)
    counts, sources, discrepancies, seen = Counter(), defaultdict(Counter), [], set()
    hashes = {}
    temporary = generation / '.calorie-audit-next.jsonl'
    with temporary.open('w') as stream:
        for group in ('consistent_candidates', 'requires_review'):
            source_file = generation / (group + '.jsonl')
            hashes[source_file.name] = hashlib.sha256(source_file.read_bytes()).hexdigest()
            with source_file.open() as rows:
                for line in rows:
                    row = json.loads(line)
                    if row['id'] in seen:
                        raise ValueError('Repeated source identity')
                    seen.add(row['id'])
                    record, classification = row['record'], row['classification']
                    nutrition = source_nutrition_for_audit(record, classification['nutrition'])
                    comparison = compare_calories(record, nutrition)
                    source = record.get('manufacturer', 'off')
                    counts[comparison['status']] += 1
                    sources[source][comparison['status']] += 1
                    output = {'id': row['id'], 'name': record['name'], 'source': source, 'basis': classification['basis'],
                              'nutrition': nutrition, 'nutrition_origin': 'original_source',
                              'imputations_not_used': record.get('nutrition_imputations', {}),
                              'working_comparison': compare_calories(record, classification['nutrition']) if record.get('nutrition_imputations') else None, 'source_url': record.get('source_url'),
                              'original_group': classification['group'], 'comparison': comparison}
                    stream.write(json.dumps(output, ensure_ascii=False, allow_nan=False) + '\n')
                    if comparison['status'] == 'discrepancy':
                        discrepancies.append(output)
    manifest = json.loads((generation / 'report.json').read_text())
    if len(seen) != manifest['input_records']:
        raise ValueError('Incomplete energy audit')
    temporary.replace(generation / 'calorie-audit.jsonl')
    discrepancies.sort(key=lambda row: (-row['comparison']['absolute_delta_kcal'], row['id']))
    report = {'scanned': len(seen), 'statuses': dict(counts), 'sources': {key: dict(value) for key, value in sources.items()},
              'tolerances': {'close_match_kcal': 2, 'absolute_kcal': 10, 'relative_fraction': .1, 'rule': 'max(absolute, relative * declared)'},
              'largest_discrepancies': discrepancies[:20], 'input_sha256': hashes, 'firebase_writes': 0,
              'notes': ['Every source identity has a result, including incomplete records.', 'Main counts compare original source values; inferred working zeros are shown separately with provenance.',
                        '4*carbs + 4*protein + 9*fat is shown independently from fiber-adjusted scenarios.',
                        'For unknown convention both physically valid fiber scenarios are tested; neither convention is assigned.',
                        'Missing fiber is not zero. Energy from polyols, alcohol and other undeclared contributors is not reconstructed.',
                        'A calorie match does not prove a per-100g basis or approval to import. No source value is changed.']}
    (generation / 'calorie-audit-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n')
    print(json.dumps({key: report[key] for key in ('scanned', 'statuses', 'sources')}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
