"""Separate internally consistent source profiles from records requiring review.

Consistency is deliberately independent from approval to publish nutrition facts.
Missing optional fiber is not a consistency failure or a manufactured zero.
"""

import math
import re
from urllib.parse import urlparse

from .macro_audit import assess_record
from .nutrition_facts import working_nutrition

CORE = ('carbs', 'fat', 'protein')


def classify(record, *, manufacturer=False, conflicting_name=False, source_verified=False):
    nutrition = record.get('nutrition', {}) if manufacturer else working_nutrition(record)
    basis = record.get('basis') if manufacturer else None
    reasons = []
    if not record.get('name', '').strip():
        reasons.append('missing_name')
    audit = assess_record({**record, 'nutrition_as_exported': nutrition, 'nutrition_imputations': {}})
    if audit['record_kind'] != 'food_or_unclassified':
        reasons.append('not_human_food')
    valid_core = True
    for key in CORE:
        value = nutrition.get(key)
        if value is None:
            reasons.append('missing_' + key)
            valid_core = False
        elif isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not 0 <= value <= 100:
            reasons.append('invalid_' + key)
            valid_core = False
    if valid_core and sum(nutrition[key] for key in CORE) > 100.5:
        reasons.append('core_mass_above_100')
    for key, maximum in [('fiber', 100), ('energy_kcal', 1000)]:
        value = nutrition.get(key)
        if value is not None and (isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not 0 <= value <= maximum):
            reasons.append('invalid_' + key)
    if basis != {'amount': 100, 'unit': 'g'}:
        reasons.append('volume_basis' if basis == {'amount': 100, 'unit': 'ml'} else 'unknown_nutrition_basis')
    if record.get('preparation') != 'as_sold':
        reasons.append('preparation_requires_review')
    if record.get('zero_fill_review_flags'):
        reasons.append('zero_fill_requires_review')
    if record.get('source_quality_errors'):
        reasons.append('source_quality_errors')
    if not manufacturer:
        # Flat OFF export cannot attest basis/convention, even with complete macros.
        reasons.append('off_label_requires_verification')
    if manufacturer and not source_verified:
        reasons.append('source_snapshot_not_verified')
    if conflicting_name:
        reasons.append('same_name_different_profiles')
    if urlparse(record.get('source_url', '')).scheme != 'https':
        reasons.append('missing_https_source')
    mode = record.get('carbs_label_mode')
    fiber = nutrition.get('fiber')
    valid_fiber = isinstance(fiber, (float, int)) and not isinstance(fiber, bool) and math.isfinite(fiber) and 0 <= fiber <= 100
    if valid_core and valid_fiber and mode != 'non_eu' and sum(nutrition[key] for key in CORE) + fiber > 100.5:
        reasons.append('fiber_mass_requires_review')
    energy = nutrition.get('energy_kcal')
    if valid_core and isinstance(energy, (float, int)) and not isinstance(energy, bool) and math.isfinite(energy):
        base = 4 * nutrition['carbs'] + 9 * nutrition['fat'] + 4 * nutrition['protein']
        estimates = [base]
        if valid_fiber:
            eu_estimate = base + 2 * fiber
            non_eu_estimate = base - 2 * fiber
            estimates = [eu_estimate] if mode == 'eu' else [non_eu_estimate] if mode == 'non_eu' else [eu_estimate, non_eu_estimate]
        if min(abs(expected - energy) for expected in estimates) > max(25, energy * .2):
            # Never replace declared energy using this screening estimate.
            reasons.append('energy_requires_review')
    blockers = list(dict.fromkeys(reasons))
    if mode not in ('eu', 'non_eu'):
        blockers.append('carbohydrate_convention_unverified')
    if mode == 'non_eu' and nutrition.get('fiber') is None:
        blockers.append('fiber_required_for_non_eu_conversion')
    if mode == 'non_eu' and valid_core and isinstance(nutrition.get('fiber'), (float, int)) and nutrition['fiber'] > nutrition['carbs']:
        blockers.append('fiber_exceeds_total_carbohydrate')
    if not record.get('publication_approved', False):
        blockers.append('publication_not_approved')
    return {
        'group': 'requires_review' if reasons else 'consistent_candidates',
        'review_reasons': sorted(set(reasons)),
        'import_blockers': sorted(set(blockers)),
        'import_ready': not blockers,
        'nutrition': nutrition,
        'basis': basis,
        'fiber_required_for_core_completeness': False,
    }
