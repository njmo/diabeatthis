"""Source-aware statistics; packaging units are hints, never nutrition evidence."""

from collections import Counter, defaultdict
import math
import re
import statistics

from .macro_audit import assess_record

CORE = ('carbs', 'fat', 'protein')
PACKAGE_UNIT = re.compile(r'\d\s*(ml|cl|dl|kg|mg|g|l)(?![a-z])', re.I)
SOLID_NAME = re.compile(r'\b(?:cukierki|krówka|krówki)\b', re.I)


def valid_number(value, maximum=100):
    return not isinstance(value, bool) and isinstance(value, (int, float)) and math.isfinite(value) and 0 <= value <= maximum


def package_unit_hint(record):
    package = record.get('package')
    if isinstance(package, dict) and package.get('unit') in ('g', 'ml'):
        return package['unit']
    units = {match.lower() for match in PACKAGE_UNIT.findall(record.get('quantity', ''))}
    kinds = {'ml' if unit in ('ml', 'cl', 'dl', 'l') else 'g' for unit in units}
    return next(iter(kinds)) if len(kinds) == 1 else 'mixed' if kinds else 'unknown'


def summarize(rows):
    sources = defaultdict(Counter)
    reasons, blockers, missing_patterns, basis_counts, quality_flags = (Counter() for _ in range(5))
    packaging = defaultdict(Counter)
    names = defaultdict(list)
    distributions = defaultdict(list)
    improvements = Counter()
    examples = defaultdict(list)
    seen = set()
    totals = Counter()
    for row in rows:
        identity = row['id']
        if identity in seen:
            raise ValueError('Repeated partition identity: ' + identity)
        seen.add(identity)
        record, result = row['record'], row['classification']
        source = record.get('manufacturer', 'off')
        nutrition = result['nutrition']
        reasons_set = set(result['review_reasons'])
        totals['records'] += 1
        sources[source]['records'] += 1
        sources[source][result['group']] += 1
        sources[source]['import_ready'] += bool(result['import_ready'])
        totals['import_ready'] += bool(result['import_ready'])
        present = all(nutrition.get(key) is not None for key in CORE)
        complete = all(valid_number(nutrition.get(key)) for key in CORE)
        missing = '+'.join(key for key in CORE if nutrition.get(key) is None) or 'none'
        missing_patterns[missing] += 1
        sources[source]['core_present'] += present
        sources[source]['core_valid_individually'] += complete
        human_food = assess_record({**record, 'nutrition_as_exported': nutrition, 'nutrition_imputations': {}})['record_kind'] == 'food_or_unclassified'
        sources[source]['excluded_non_food_or_pet'] += not human_food
        sources[source]['human_food_core_valid'] += complete and human_food
        sources[source]['core_valid_without_fiber'] += complete and nutrition.get('fiber') is None
        basis = result.get('basis')
        unit = basis['unit'] if basis and basis.get('amount') == 100 and basis.get('unit') in ('g', 'ml') else 'unknown'
        basis_counts[unit] += 1
        sources[source]['basis_' + unit] += 1
        sources[source]['core_valid_basis_g'] += complete and unit == 'g'
        packaging[source][package_unit_hint(record)] += 1
        reasons.update(reasons_set)
        blockers.update(result['import_blockers'])
        quality_flags.update(record.get('source_quality_errors') or [])
        names[(source, record.get('brand', '').strip().casefold(), record['name'].strip().casefold())].append(row)
        if complete and human_food:
            for key in CORE:
                distributions[(unit, key)].append(nutrition[key])
        if result['group'] == 'consistent_candidates':
            improvements['current_consistent_g'] += 1
        volume_conflict = unit == 'ml' and bool(SOLID_NAME.search(record['name']))
        if volume_conflict:
            improvements['ml_with_suspect_solid_label'] += 1
        if reasons_set == {'volume_basis'}:
            improvements['ml_only_partition_blocker'] += 1
            if not volume_conflict:
                improvements['additional_candidates_with_ml_support'] += 1
                sources[source]['additional_candidates_with_ml_support'] += 1
        for reason in reasons_set | ({'suspect_solid_volume_label'} if volume_conflict else set()):
            if len(examples[reason]) < 5:
                examples[reason].append({'id': identity, 'name': record['name'], 'source': source, 'nutrition': nutrition, 'basis': basis, 'source_url': record.get('source_url')})
    duplicate_groups = [group for group in names.values() if len(group) > 1]
    conflicting = []
    for group in duplicate_groups:
        profiles = {(tuple(row['classification']['nutrition'].get(key) for key in CORE), str(row['classification'].get('basis'))) for row in group}
        if len(profiles) > 1:
            conflicting.append([row['id'] for row in group])
    improvements['candidates_after_ml_support'] = improvements['current_consistent_g'] + improvements['additional_candidates_with_ml_support']
    quantiles = defaultdict(dict)
    for (unit, key), values in distributions.items():
        values.sort()
        quantiles[unit][key] = {'count': len(values), 'min': values[0], 'median': statistics.median(values), 'p95_nearest_rank': values[math.ceil(.95 * len(values)) - 1], 'max': values[-1]}
    return {
        'totals': dict(totals), 'sources': {key: dict(value) for key, value in sorted(sources.items())},
        'missing_core_patterns': dict(missing_patterns), 'nutrition_basis': dict(basis_counts),
        'packaging_unit_hints_not_nutrition_basis': {key: dict(value) for key, value in sorted(packaging.items())},
        'review_reasons_overlapping': dict(reasons.most_common()), 'import_blockers_overlapping': dict(blockers.most_common()),
        'source_quality_flags': dict(quality_flags.most_common()), 'ml_support_scenario': dict(improvements),
        'grams_only_scope': {'declared_100g_records': basis_counts['g'], 'complete_core_100g_records': sum(source['core_valid_basis_g'] for source in sources.values()), 'consistent_candidates': improvements['current_consistent_g']},
        'same_source_brand_name_duplicates': {'groups': len(duplicate_groups), 'records': sum(map(len, duplicate_groups)), 'different_core_profile_groups': len(conflicting)},
        'macro_distributions_valid_human_food_rows_by_basis': dict(quantiles),
        'examples_by_review_reason': dict(sorted(examples.items())),
        'notes': ['Counts are source records, not deduplicated physical products; source IDs are retained.',
                  'Consistent means screened source data, not independent validation of every label.',
                  'Package units cannot establish the unit of a nutrition table.',
                  'The ml scenario removes only the volume limitation; it does not approve EU/US convention or publication.',
                  'Missing fiber is optional for core completeness. No missing value is converted to zero.',
                  'Reason counts overlap and must not be summed as product counts.'],
    }
