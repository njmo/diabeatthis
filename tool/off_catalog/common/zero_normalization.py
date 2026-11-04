"""Coordinate source zeros and composition rules without hiding contradictory evidence."""

from .source_zero_macros import apply_source_zeros
from .type_zero_macros import apply_type_zeros


def normalize_zeros(record,profiles=()):
    result=apply_source_zeros(record,profiles)
    nonzero_fields={key for p in profiles if p.get('preparation')=='as_sold'
                    for key,value in p.get('nutrition',{}).items()
                    if key in ('carbs','fat','protein') and isinstance(value,(int,float)) and value>0}
    return apply_type_zeros(result,nonzero_source_fields=nonzero_fields)
