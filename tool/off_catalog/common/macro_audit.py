"""Classify required macros separately from optional nutrition and identity gaps."""

import math
import re
from .products import search_text
from .nutrition_facts import working_nutrition

CORE = ('carbs', 'fat', 'protein')
NON_FOOD = re.compile(r'\b(?:szampon|henna|farba|farby|emalia|emakol|lakier|lakierobejca|antykorozyjny|drzwi|futryna|oscieznica|chusteczki|dezodorant|perfumy|pasta do zebow|zel pod prysznic|plyn do mycia|proszek do prania|plyn do plukania|krem do rak|krem do twarzy|wiertlo|wkret|gwozdzie)\b')
NON_FOOD_BRANDS = {'dek', 'dre', 'kb', 'nivea', 'garnier', 'maybelline', 'durex', 'delia cosmetics', 'eveline cosmetics', 'alverde naturkosmetik'}


def assess_record(record):
    values = working_nutrition(record)
    missing, invalid, range_review = [], [], []
    for key in CORE:
        value = values.get(key)
        if value is None:
            missing.append(key)
        elif isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
            invalid.append(key)
        elif value > 100:
            range_review.append(key)
    name, brand = search_text(record.get('name', '')), search_text(record.get('brand', '')).strip()
    kind = 'non_food' if NON_FOOD.search(name) or brand in NON_FOOD_BRANDS else 'food_or_unclassified'
    if re.search(r'\bkarma\b.*\b(?:kot|kota|kotow|psa|psow|pies)\b', name):
        kind = 'pet_food'
    pattern = '+'.join(missing) if missing else 'none'
    status = 'invalid_core_values' if invalid else 'missing_core_macros' if missing else 'range_review' if range_review else 'complete_core_macros'
    if kind in ('non_food', 'pet_food'):
        route = 'excluded_from_human_food_catalog'
    elif status == 'complete_core_macros':
        route = 'core_complete'
    elif not record.get('brand', '').strip():
        route = 'identity_needs_review'
    else:
        route = 'manufacturer_catalog_or_exception'
    if record.get('zero_fill_review_flags') and kind not in ('non_food','pet_food'):
        route = 'zero_fill_inference_review'
    return {'zero_fill_review_flags':record.get('zero_fill_review_flags',[]),'status': status, 'missing_core_fields': missing, 'missing_pattern': pattern,
            'invalid_core_fields': invalid, 'range_review_fields': range_review,
            'fiber_reported': values.get('fiber') is not None, 'fiber_required': False,
            'energy_required': False, 'record_kind': kind, 'route': route}
