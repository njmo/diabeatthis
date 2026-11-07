#!/usr/bin/env python3
"""Analyze both complete partition files without contacting external services."""

import hashlib
import json
from pathlib import Path

from common.catalog_statistics import summarize

ROOT = Path(__file__).resolve().parent


def main():
    generation = (ROOT / 'data/partition/current').resolve(strict=True)
    files = [generation / (group + '.jsonl') for group in ('consistent_candidates', 'requires_review')]
    hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
    manifest = json.loads((generation / 'report.json').read_text())

    def rows():
        for path in files:
            for line in path.open():
                row = json.loads(line)
                if row['classification']['group'] != path.stem:
                    raise ValueError('Wrong partition membership: ' + row['id'])
                yield row

    report = summarize(rows())
    if report['totals']['records'] != manifest['input_records']:
        raise ValueError('Partition count does not match the generation manifest')
    for group in ('consistent_candidates', 'requires_review'):
        if sum(source.get(group, 0) for source in report['sources'].values()) != manifest['counts'].get(group, 0):
            raise ValueError('Partition bucket count does not match the manifest')
    report.update(partition_generation=generation.name, input_sha256=hashes, firebase_writes=0, external_requests=0)
    destination = generation / 'statistics.json'
    temporary = generation / '.statistics-next.json'
    temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n')
    temporary.replace(destination)
    print(json.dumps({key: report[key] for key in ('totals', 'sources', 'nutrition_basis', 'ml_support_scenario', 'missing_core_patterns')}, ensure_ascii=False, indent=2))
    print('Statistics saved:', destination)


if __name__ == '__main__':
    main()
