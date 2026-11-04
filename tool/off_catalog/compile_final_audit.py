#!/usr/bin/env python3
"""Reconcile all research without inventing missing macros or mixing nutrition bases."""

from collections import Counter, defaultdict
import csv
import json
import math
from pathlib import Path
import sqlite3
from common.nutrition_facts import working_nutrition

ROOT=Path(__file__).resolve().parent
CORE=('carbs','fat','protein')


def valid_profile(source):
    basis=source.get('basis')
    if basis is None and source.get('basis_amount')==100:
        basis={'amount':100,'unit':source.get('basis_unit')}
    values=source.get('nutrition',{})
    if basis not in ({'amount':100,'unit':'g'},{'amount':100,'unit':'ml'}):return None
    if any(isinstance(values.get(k),bool) or not isinstance(values.get(k),(int,float)) or not math.isfinite(values[k]) or values[k]<0 or values[k]>100 for k in CORE):return None
    if source.get('preparation')=='prepared':return None
    url=source.get('url') or source.get('source_url')
    if not url or not url.startswith('https://') or 'google.com/search' in url:return None
    return {'nutrition':dict(values),'basis':basis,'source_url':url,'identity_evidence':source.get('identity_evidence'),
            'preparation':source.get('preparation','unknown'),'carbs_label_mode':'unknown','publication_approved':False}


def reconcile():
    output=ROOT/'data/final_audit';output.mkdir(exist_ok=True)
    profiles=defaultdict(list);research=defaultdict(list)
    for file in sorted(output.glob('partial_*_result.json')):
        result=json.loads(file.read_text());inp=json.loads(file.with_name(file.name.replace('_result','_input')).read_text())
        expected={'off_'+r['source_id'] for r in inp['records']}
        actual={r['target_id'] for r in result['records']}
        if expected!=actual or len(actual)!=len(result['records']):raise ValueError('Research coverage mismatch: '+str(file))
        for record in result['records']:
            research[record['target_id']].append(record['status'])
            if record['status']=='source_backed_profile':
                for source in record['sources']:
                    profile=valid_profile(source)
                    if profile:profiles[record['target_id']].append(profile)
    previous=ROOT/'data/enrichment/proposals.jsonl'
    if previous.exists():
        for line in previous.read_text().splitlines():
            row=json.loads(line)
            if row['validation']['status']!='source_backed_proposal':continue
            for source in row['validation']['sources']:
                profile=valid_profile(source)
                if profile:profiles['off_'+row['code']].append(profile)
    automatic=ROOT/'data/bulk_matches/proposals.jsonl'
    if automatic.exists():
        for line in automatic.read_text().splitlines():
            row=json.loads(line)
            source={'nutrition':row.get('nutrition_proposal',{}),'basis':row.get('basis'),'source_url':row.get('source_url'),'preparation':'as_sold'}
            profile=valid_profile(source)
            if profile:profiles[row['target_id']].append(profile)
    global_candidates={}
    global_file=ROOT/'data/global_matches/candidates.jsonl'
    if global_file.exists():
        global_candidates={r['target_id']:r for r in (json.loads(line) for line in global_file.read_text().splitlines())}
    statuses,patterns,raw_patterns=Counter(),Counter(),Counter()
    raw_partial_records=0
    working_partial_records=0
    original_manifest=json.loads((ROOT/'data/poland/current/macro_audit.json').read_text())
    with sqlite3.connect(f'file:{(ROOT / "data/poland/current/catalog.sqlite").resolve()}?mode=ro',uri=True) as db, (output/'all_named_records.jsonl').open('w',encoding='utf-8') as allrows, (output/'core_complete_for_review.jsonl').open('w',encoding='utf-8') as usable, (output/'remaining_gaps.csv').open('w',newline='',encoding='utf-8') as gapfile:
        writer=csv.writer(gapfile);writer.writerow(['id','name','brand','missing_core','assessment','research_status','source_urls'])
        for (payload,) in db.execute('SELECT document FROM products ORDER BY code'):
            record=json.loads(payload);audit=record['macro_audit'];choices=profiles.get(record['id'],[])
            raw_missing=[k for k in CORE if record['nutrition_as_exported'].get(k) is None]
            if raw_missing:raw_patterns['+'.join(raw_missing)]+=1
            raw_partial_records+=0<len(raw_missing)<3
            working_partial_records+=0<len(audit['missing_core_fields'])<3
            unique={json.dumps(p,sort_keys=True) for p in choices};choices=[json.loads(p) for p in sorted(unique)]
            status='missing_source_profile'
            chosen=None
            if audit['record_kind'] in ('non_food','pet_food'):status='excluded_non_food_or_pet_food'
            elif record.get('zero_fill_review_flags'):status='zero_fill_requires_review'
            elif audit['status']=='complete_core_macros':status='reported_core_complete'
            elif choices:
                first=choices[0]
                conflicts=any(p['basis']!=first['basis'] or any(not math.isclose(p['nutrition'][k],first['nutrition'][k],abs_tol=0.05,rel_tol=0) for k in CORE) for p in choices[1:])
                if conflicts:status='conflicting_source_profiles'
                else:
                    status='source_profile_available_for_review'
                    chosen=max(choices,key=lambda p:sum(v is not None for v in p['nutrition'].values()))
                    existing=record['nutrition_as_exported']
                    if any(existing.get(k) is not None and not math.isclose(existing[k],chosen['nutrition'][k],abs_tol=0.05,rel_tol=0) for k in CORE):
                        status='source_profile_requires_existing_fact_review'
            elif audit['status']=='range_review':status='range_requires_review'
            elif not record['brand'].strip():status='identity_and_full_profile_required'
            statuses[status]+=1
            row={'record':record,'assessment':status,'source_profiles':choices,'nutrition_profile_for_review':chosen,
                 'research_status':research.get(record['id'],[]),'alternate_off_candidates':global_candidates.get(record['id']), 'publication_approved':False,'fiber_required':False}
            text=json.dumps(row,ensure_ascii=False,allow_nan=False)+'\n';allrows.write(text)
            if status in ('reported_core_complete','source_profile_available_for_review'):usable.write(text)
            else:
                if status=='excluded_non_food_or_pet_food':continue
                patterns['+'.join(audit['missing_core_fields']) or 'range_or_category_review']+=1
                safe=lambda s:"'"+s if s.startswith(('=','+','-','@','\t','\r')) else s
                writer.writerow([record['id'],safe(record['name']),safe(record['brand']),';'.join(audit['missing_core_fields']),status,';'.join(row['research_status']),';'.join(p['source_url'] for p in choices)])
    report={'required_fields':list(CORE),'fiber_required':False,'unnamed_removed':original_manifest.get('removed_without_name_total',original_manifest['counts'].get('removed_without_name',0)),
            'named_records_classified':sum(statuses.values()),'original_missing_patterns':dict(raw_patterns),'working_missing_patterns':original_manifest['missing_patterns'],
            'original_partial_macro_records':raw_partial_records,'working_partial_macro_records':working_partial_records,
            'final_assessments':dict(statuses),'remaining_patterns':dict(patterns),'partial_macro_records_researched':len(research),
            'firebase_writes':0,'paid_ai_api_calls':0,
            'global_off_scan':json.loads((ROOT/'data/global_matches/manifest.json').read_text()) if (ROOT/'data/global_matches/manifest.json').exists() else None,
            'scope_notes':['Every named local record is classified. Optional fiber never makes an otherwise complete macro profile incomplete.',
                           'Full profiles remain necessary where all three macros are absent; unresolved does not mean zero.',
                           'Source profiles are atomic review proposals and do not overwrite source or application history.',
                           'A complete C/P/F report is separate from physical-basis, carbohydrate-convention, identity and publication-rights checks.']}
    (output/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
    return report


if __name__=='__main__':reconcile()
