#!/usr/bin/env python3
"""Print ten reviewed examples and apply the same deterministic filter to all rows."""

from collections import Counter
import hashlib
import json
from pathlib import Path

from common.incomplete_record_filter import assess_entry

ROOT = Path(__file__).resolve().parent
SAMPLE_IDS = ['lowicz_7c753e0a0ef09a60b9bd', 'off_0049000057997', 'off_00590259', 'off_0200030154289', 'off_20585624', 'off_2900207002501', 'off_0590270433566', 'off_0000102001000', 'off_01808360', 'off_0590490091904']


def main():
    source = (ROOT / 'data/partition/current').resolve(strict=True)
    counts, missing, examples, seen = Counter(), Counter(), {}, set()
    hashes = {}
    output = source / '.entry-filter-next.jsonl'
    with output.open('w') as stream:
        for group in ('consistent_candidates', 'requires_review'):
            file = source / (group + '.jsonl')
            hashes[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
            with file.open() as rows:
                for line in rows:
                    row = json.loads(line)
                    if row['id'] in seen:
                        raise ValueError('Duplicate source identity')
                    seen.add(row['id'])
                    assessment = assess_entry(row)
                    counts[assessment['route']] += 1
                    missing['+'.join(assessment['missing_core']) or 'none'] += 1
                    record = row['record']
                    result = {'id': row['id'], 'name': record['name'], 'brand': record.get('brand', record.get('manufacturer')), 'source_url': record.get('source_url'), 'nutrition': row['classification']['nutrition'], 'basis': row['classification']['basis'], 'assessment': assessment}
                    stream.write(json.dumps(result, ensure_ascii=False, allow_nan=False) + '\n')
                    if row['id'] in SAMPLE_IDS:
                        examples[row['id']] = result
    manifest = json.loads((source / 'report.json').read_text())
    if len(seen) != manifest['input_records']:
        raise ValueError('Incomplete scan')
    output.replace(source / 'entry-filter.jsonl')
    report = {'scanned_records': len(seen), 'routes': dict(counts), 'missing_patterns': dict(missing), 'input_sha256': hashes,
              'samples': [examples[key] for key in SAMPLE_IDS if key in examples], 'firebase_writes': 0, 'nutrition_values_changed': 0,
              'notes': ['Rules derive from ten inspected examples; every available source record is scanned.', 'Structural zeros are proposals only and never resolve unknown physical basis or carbohydrate convention.', 'Incomplete profiles are not reconstructed from energy, similar product names, or category averages.']}
    (source / 'entry-filter-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: report[key] for key in ('scanned_records', 'routes', 'missing_patterns')}, ensure_ascii=False, indent=2))
    for sample in report['samples']:
        print(json.dumps(sample, ensure_ascii=False))


if __name__ == '__main__':
    main()
