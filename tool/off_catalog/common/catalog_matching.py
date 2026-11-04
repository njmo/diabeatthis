"""Deterministic catalog matching: barcode is optional, identity evidence is not."""

from difflib import SequenceMatcher
import math
import re
from .products import search_text
from .enrichment import CORE, NUTRIENT_KEYS
from .catalog_parsers import package

ALIASES = {'sante': ('sante','lovege'), 'lowicz': ('lowicz','osm lowicz'), 'mlekovita': ('mlekovita', 'mlekovit'), 'piatnica': ('piatnica', 'osm piatnica'), 'bakoma': ('bakoma',)}


def normalized(value):
    return ' '.join(re.findall(r'\d+(?:[.,]\d+)?|[^\W\d_]+|%', search_text(value).replace(',', '.')))


def manufacturer_matches(original, manufacturer):
    brand = search_text(original.get('brand', ''))
    return any(re.search(r'(?<!\w)' + re.escape(alias) + r'(?!\w)', brand) for alias in ALIASES.get(manufacturer, (manufacturer,)))


def name_identity(value, manufacturer):
    value = search_text(value)
    # Strip package quantities, never fat percentages or flavor/claim words.
    value = re.sub(r'(?<!\w)\d+(?:[.,]\d+)?\s*(?:kg|ml|g|l)\b', ' ', value)
    for alias in ALIASES.get(manufacturer, (manufacturer,)):
        value = re.sub(r'(?<!\w)' + re.escape(alias) + r'(?!\w)', ' ', value)
    return ' '.join(sorted(normalized(value).split()))


def packages_compatible(original, source):
    quantities = [package(original.get('quantity', '')), package(original.get('name', '')),
                  source.get('package'), package(source.get('name', ''))]
    if any(value and value.get('ambiguous_multipack') for value in quantities):
        return False
    known = [value for value in quantities if value]
    return not known or all(value['unit'] == known[0]['unit'] and math.isclose(value['amount'], known[0]['amount'], abs_tol=0.01) for value in known)


def match_product(original, products):
    pool = [p for p in products if manufacturer_matches(original, p['manufacturer']) and name_identity(p['name'], p['manufacturer'])]
    if not any(name_identity(original['name'], p['manufacturer']) for p in pool):
        return {'status': 'exception', 'reason': 'missing_food_identity', 'candidates': []}
    exact = [p for p in pool if original['source_id'] in p['barcodes']]
    if exact:
        barcode_candidates = [p['id'] for p in exact]
        # Exact code does not justify changing the nutrition of an unrelated food.
        left = set(name_identity(original['name'], exact[0]['manufacturer']).split())
        exact = [p for p in exact if packages_compatible(original, p) and left == set(name_identity(p['name'], p['manufacturer']).split())]
        if not exact:
            return {'status': 'exception', 'reason': 'barcode_name_conflict', 'candidates': barcode_candidates}
        selected, method = exact, 'barcode'
    else:
        selected = [p for p in pool if name_identity(original['name'], p['manufacturer']) == name_identity(p['name'], p['manufacturer']) and packages_compatible(original, p)]
        method = 'exact_manufacturer_name_variant'
    if len(selected) != 1:
        target = normalized(original['name'])
        ranked = sorted(pool, key=lambda p: SequenceMatcher(None, target, normalized(p['name'])).ratio(), reverse=True)
        return {'status': 'exception', 'reason': 'ambiguous_identity' if selected else 'no_exact_identity',
                'candidates': [p['id'] for p in (selected or ranked[:3])]}
    source = selected[0]
    if method != 'barcode' and original['source_id'].isdigit() and source['barcodes']:
        return {'status': 'exception', 'reason': 'barcode_disagreement', 'candidates': [source['id']]}
    errors = []
    if source.get('preparation') != 'as_sold':
        errors.append('preparation_basis_requires_review')
    if source.get('basis') not in ({'amount': 100, 'unit': 'g'}, {'amount': 100, 'unit': 'ml'}):
        errors.append('unknown_nutrition_basis')
    values = source['nutrition']
    for key in NUTRIENT_KEYS:
        value = values.get(key)
        if value is None:
            if key in CORE:
                errors.append('missing_' + key)
            continue
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0 or (key != 'energy_kcal' and value > 100):
            errors.append('invalid_' + key)
    if not errors and sum(values[k] for k in CORE) > 105:
        errors.append('inconsistent_macro_sum')
    missing_field_candidates = {}
    for key in NUTRIENT_KEYS:
        previous, value = original['nutrition_as_exported'].get(key), values.get(key)
        if previous is None and value is not None:
            missing_field_candidates[key] = value
        elif previous is not None and value is not None and not math.isclose(previous, value, abs_tol=0.05, rel_tol=0):
            errors.append('existing_nutrition_conflict_' + key)
    return {'status': 'exception' if errors else 'source_backed_proposal', 'match_method': method,
            'reason': ';'.join(sorted(errors)), 'candidates': [source['id']], 'missing_field_candidates': {} if errors else missing_field_candidates,
            'nutrition_proposal': None if errors else dict(values),
            'apply_strategy': 'replace_complete_nutrition_after_review',
            'retains_original_nutrient_values': False,
            'basis': source['basis'], 'source_url': source['source_url'], 'source_sha256': source['source_sha256'],
            'barcode_required': False, 'publication_approved': False}
