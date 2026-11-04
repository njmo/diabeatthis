"""Explicit, user-authorized structural zeros for narrowly identified commodities."""

import copy
import re
from .nutrition_facts import working_nutrition
from .products import search_text

CORE=('carbs','fat','protein')
MODIFIERS=r'(?:ekologiczny |bio |organic |virgin |extra virgin )*'
OIL_PLANT=r'(?:rzepakowy|slonecznikowy|kokosowy|lniany|sojowy|kukurydziany|sezamowy|arachidowy|z ostropestu|z czarnuszki|z pestek winogron|z zarodkow rzepaku|z awokado)'
OIL=re.compile(r'^(?:'+MODIFIERS+r'olej '+OIL_PLANT+r'(?: ekologiczny| nierafinowany| rafinowany| virgin| tloczony na zimno| zimnotloczony)*|oliwa z oliwek(?: z pierwszego tloczenia| extra virgin| virgin| rafinowana)*|(?:avocado|coconut|olive|canola|sunflower|rapeseed|flaxseed|soybean) oil(?: virgin| extra virgin| organic)*)$')
SUGAR=re.compile(r'^(?:white sugar|granulated sugar|cane sugar(?: cubes| royal)?|cukier(?: bialy| krysztal| puder| trzcinowy| w kostkach)?|sugar cubes)$')
WATER=re.compile(r'^(?:woda(?: zrodlana| mineralna| naturalna| niegazowana| gazowana| mocny gaz| lekko gazowana| stolowa)*|(?:plain |mineral |spring |sparkling |still )*water)$')
SALT=re.compile(r'^(?:sol(?: kuchenna| jodowana| niejodowana| morska| kamienna| himalajska| rozowa)*|(?:table |sea |iodized |pink |himalayan )*salt)$')


def identify_family(record):
    text=search_text(record.get('name','')).strip()
    text=re.sub(r'(?<!\w)\d+(?:[.,]\d+)?\s*(?:kg|ml|g|l)\b',' ',text)
    text=re.sub(r'\s+',' ',text.replace(' - ',' ')).strip()
    if OIL.fullmatch(text):return 'pure_oil',('carbs','protein')
    if SUGAR.fullmatch(text):return 'plain_sugar',('fat','protein')
    if WATER.fullmatch(text):return 'plain_water',CORE
    if SALT.fullmatch(text):return 'plain_salt',CORE
    return None,()


def apply_type_zeros(record, nonzero_source_fields=()):
    result=copy.deepcopy(record)
    values=working_nutrition(record)
    missing=[k for k in CORE if values.get(k) is None]
    # This pass handles partial records only; no primary fat/carb amount is invented.
    if not 0<len(missing)<3 and not result.get('nutrition_imputations'):return result
    if record.get('macro_audit',{}).get('record_kind') in ('non_food','pet_food'):return result
    family,zero_fields=identify_family(record)
    if family is None:return result
    flags=set(record.get('zero_fill_review_flags',[]))
    source_flags=set(record.get('source_review_flags',record.get('review_flags',[])))
    original_values=dict(values)
    patch={k:0.0 for k in zero_fields if values.get(k) is None and 'invalid_'+k not in source_flags and k not in nonzero_source_fields}
    for key in zero_fields:
        if key in nonzero_source_fields and values.get(key) is None:
            flags.add('nonzero_source_prevents_type_zero_'+key)
    for key in zero_fields:
        if values.get(key) is not None and values[key]!=0:
            flags.add('existing_'+key+'_contradicts_'+family)
    if family=='pure_oil' and values.get('fat') is not None and not 80<=values['fat']<=100:
        flags.add('oil_fat_basis_or_identity_requires_review')
    if family=='plain_sugar' and values.get('carbs') is not None and not 95<=values['carbs']<=100:
        flags.add('sugar_carbs_basis_or_identity_requires_review')
    if flags:result['zero_fill_review_flags']=sorted(flags)
    if not patch:return result
    result['nutrition_working']=dict(values,**patch)
    provenance=result.setdefault('nutrition_imputations',{})
    for key in patch:
        provenance[key]={'value':0.0,'previous_value':None,'rule_id':family+'_structural_zero_v1',
                         'method':'type_based_zero_imputation','user_authorized':True,
                         'identity_evidence':{'name':record['name'],'categories_tags':record.get('categories_tags',[])},
                         'manufacturer_reported':False}
    if flags:result['zero_fill_review_flags']=sorted(flags)
    result['review_flags']=[f for f in result.get('review_flags',[]) if f not in {'missing_'+k for k in patch}]
    assert all(result['nutrition_working'][k]==v for k,v in original_values.items() if v is not None)
    assert result['nutrition_as_exported']==record['nutrition_as_exported']
    return result
