"""Read authoritative source facts plus explicit, missing-only zero derivations."""


def working_nutrition(record):
    values=dict(record['nutrition_as_exported'])
    for key,derivation in record.get('nutrition_imputations',{}).items():
        if key in ('carbs','fat','protein') and values.get(key) is None and derivation.get('value')==0:
            values[key]=0.0
    return values
