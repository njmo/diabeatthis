"""Compare label energy with explicit macro scenarios without changing source facts."""

import math
import re

CORE = ('carbs', 'protein', 'fat')


def valid(value, maximum):
    return not isinstance(value, bool) and isinstance(value, (int, float)) and math.isfinite(value) and 0 <= value <= maximum


def source_nutrition_for_audit(record, working):
    """A consistency check of declared facts must not silently use inferred zeros."""
    return dict(record.get('nutrition_as_exported', working))


def compare_calories(record, nutrition, *, absolute_tolerance=10, relative_tolerance=.1):
    if not valid(absolute_tolerance, 1000) or not valid(relative_tolerance, 1):
        raise ValueError('Invalid comparison tolerance')
    missing = [key for key in CORE if nutrition.get(key) is None]
    invalid = [key for key in CORE if nutrition.get(key) is not None and not valid(nutrition[key], 100)]
    kcal = nutrition.get('energy_kcal')
    result = {'declared_kcal': kcal, 'missing_core': missing, 'invalid_core': invalid, 'scenarios': [],
              'carbs_label_mode': record.get('carbs_label_mode', 'unknown'), 'changes_to_source': False}
    if missing or invalid:
        return dict(result, status='incomplete_or_invalid_macros')
    base = 4 * nutrition['carbs'] + 4 * nutrition['protein'] + 9 * nutrition['fat']
    result['basic_4_4_9_kcal'] = round(base, 6)
    if kcal is None:
        return dict(result, status='missing_declared_kcal')
    if not valid(kcal, 1000):
        return dict(result, status='invalid_declared_kcal')
    fiber = nutrition.get('fiber')
    mode = record.get('carbs_label_mode', 'unknown')
    if fiber is not None and not valid(fiber, 100):
        return dict(result, status='invalid_fiber')
    if mode == 'non_eu' and fiber is not None and fiber > nutrition['carbs']:
        return dict(result, status='invalid_fiber_total_carbs_relation')
    if fiber is None:
        scenarios = [('basic_without_known_fiber', base)]
    elif mode == 'eu':
        scenarios = [('eu_separate_fiber', base + 2 * fiber)]
    elif mode == 'non_eu':
        scenarios = [('non_eu_included_fiber', base - 2 * fiber)]
    else:
        scenarios = [('eu_separate_fiber_scenario', base + 2 * fiber)]
        if fiber <= nutrition['carbs']:
            scenarios.append(('non_eu_included_fiber_scenario', base - 2 * fiber))
    for name, estimate in scenarios:
        result['scenarios'].append({'name': name, 'calculated_kcal': round(estimate, 6), 'absolute_delta_kcal': round(abs(estimate - kcal), 6)})
    best = min(result['scenarios'], key=lambda value: value['absolute_delta_kcal'])
    delta = best['absolute_delta_kcal']
    tolerance = max(absolute_tolerance, relative_tolerance * kcal)
    result.update(closest_scenario=best['name'], absolute_delta_kcal=delta,
                  relative_delta_percent=round(100 * delta / kcal, 3) if kcal else None,
                  tolerance_kcal=round(tolerance, 6),
                  fiber_unreported=fiber is None,
                  possible_polyol_product=bool(re.search(r'ksylitol|xylitol|erytrytol|erythritol|maltitol|sorbitol', record.get('name', ''), re.I)),
                  interpretation='Consistency screening only; not proof of nutrition basis, convention or import readiness.')
    return dict(result, status='close_match' if delta <= 2 else 'within_tolerance' if delta <= tolerance else 'discrepancy')
