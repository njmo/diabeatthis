"""Route missing source facts without confusing absent values with zero."""

import re

from .catalog_statistics import valid_number
from .products import search_text
from .type_zero_macros import identify_family

CORE = ('carbs', 'fat', 'protein')
PLAIN_SUGAR_NAMES = {'sucre blanc', 'sucre en poudre', 'weisser zucker', 'weißer zucker', 'zucchero bianco', 'azucar blanco'}


def assess_entry(row):
    record, classification = row['record'], row['classification']
    nutrition = classification['nutrition']
    reasons = set(classification['review_reasons'])
    missing = [key for key in CORE if nutrition.get(key) is None]
    invalid = [key for key in CORE if nutrition.get(key) is not None and not valid_number(nutrition[key])]
    family, zeros = identify_family(record)
    normalized = re.sub(r'\s+', ' ', search_text(record['name']).strip())
    if normalized in PLAIN_SUGAR_NAMES:
        family, zeros = 'plain_sugar', ('fat', 'protein')
    zero_proposal = {}
    source_flags = set(record.get('source_review_flags', record.get('review_flags', [])))
    # A narrow structural-zero proposal is never an approved fact or a basis conversion.
    primary_ok = (family == 'plain_sugar' and valid_number(nutrition.get('carbs')) and nutrition['carbs'] >= 95) or (family == 'pure_oil' and valid_number(nutrition.get('fat')) and nutrition['fat'] >= 80)
    if primary_ok and 0 < len(missing) < 3 and not invalid and not record.get('zero_fill_review_flags'):
        contradictory = any(nutrition.get(key) is not None and nutrition[key] != 0 for key in zeros)
        if not contradictory and not any('invalid_' + key in source_flags for key in missing):
            zero_proposal = {key: 0 for key in missing if key in zeros}
    if 'not_human_food' in reasons:
        route = 'exclude_non_food'
        zero_proposal = {}
    elif invalid:
        route = 'invalid_core_values'
        zero_proposal = {}
    elif missing and zero_proposal and set(zero_proposal) == set(missing):
        route = 'structural_zero_candidate_requires_verification'
    elif len(missing) == 3:
        route = 'whole_nutrition_profile_required'
    elif missing:
        route = 'partial_nutrition_profile_required'
    elif classification['import_ready']:
        route = 'ready_entry'
    elif classification['group'] == 'consistent_candidates':
        route = 'complete_profile_requires_import_metadata'
    else:
        route = 'complete_profile_requires_quality_or_basis_review'
    blockers = list(classification['import_blockers'])
    if zero_proposal:
        blockers.append('structural_zero_proposal_not_applied')
    return {
        'route': route, 'missing_core': missing, 'invalid_core': invalid,
        'structural_zero_proposal': zero_proposal,
        'can_create_entry': route == 'ready_entry',
        'blockers': sorted(set(blockers)),
        'missing_fiber_is_not_a_core_gap': nutrition.get('fiber') is None,
        'raw_missing_fields': [key for key in missing if not record['raw_nutrition'].get({'carbs': 'carbohydrates_100g', 'fat': 'fat_100g', 'protein': 'proteins_100g'}[key], '').strip()] if 'raw_nutrition' in record else None,
    }
