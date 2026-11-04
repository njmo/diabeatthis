"""Reuse explicit source-reported zeros, which are invariant to gram/ml scaling."""

import copy
import math
from .nutrition_facts import working_nutrition

CORE=('carbs','fat','protein')


def apply_source_zeros(record,profiles):
    result=copy.deepcopy(record)
    values=working_nutrition(record)
    if not 0<sum(values.get(k) is None for k in CORE)<3 and not record.get('nutrition_imputations'):return result
    if record.get('macro_audit',{}).get('record_kind') in ('non_food','pet_food'):return result
    profiles=[p for p in profiles if p.get('preparation')=='as_sold']
    source_flags=set(record.get('source_review_flags',record.get('review_flags',[])))
    patch={};evidence={}
    for key in CORE:
        if values.get(key) is not None or 'invalid_'+key in source_flags:continue
        observations=[p for p in profiles if isinstance(p.get('nutrition',{}).get(key),(int,float)) and not isinstance(p['nutrition'][key],bool)]
        if observations and all(p['nutrition'][key]==0 for p in observations):
            patch[key]=0.0;evidence[key]=[p['source_url'] for p in observations]
    flags=set(result.get('zero_fill_review_flags',[]))
    for p in profiles:
        for key in CORE:
            existing=values.get(key);found=p.get('nutrition',{}).get(key)
            if existing is not None and found is not None and not math.isclose(existing,found,abs_tol=0.05,rel_tol=0):
                flags.add('source_'+key+'_differs_from_existing')
    if flags:result['zero_fill_review_flags']=sorted(flags)
    if not patch:return result
    result['nutrition_working']=dict(values,**patch)
    for key in patch:
        result.setdefault('nutrition_imputations',{})[key]={'value':0.0,'previous_value':None,
            'method':'source_reported_zero','source_urls':sorted(set(evidence[key])),
            'source_reported':True,'publication_approved':False}
    if flags:result['zero_fill_review_flags']=sorted(flags)
    result['review_flags']=[f for f in result.get('review_flags',[]) if f not in {'missing_'+k for k in patch}]
    assert result['nutrition_as_exported']==record['nutrition_as_exported']
    return result
