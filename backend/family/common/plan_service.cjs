'use strict';
const {FamilyError, exact, hash} = require('./security.cjs');
const {familyContext} = require('./mirror_service.cjs');
const {validatePlan, scopeRows, versions} = require('./plan_contract.cjs');
const fail = code => { throw new FamilyError(code); };
function createPlanService({store}) {
  const root = uid => store.doc(`userMirrors/${uid}`);
  const operation = (uid,id) => root(uid).collection('plans').doc(id);
  const lock = (uid,key) => root(uid).collection('planLocks').doc(key);
  async function rate(uid,action,limit) {
    const ref=store.doc(`familyRateLimits/${hash(uid+':plan:'+action)}`);
    await store.runTransaction(async tx=>{
      const old=(await tx.get(ref)).data();const now=Date.now();const same=old&&old.start+60000>now;
      const count=same?old.count+1:1;if(count>limit) fail('resource-exhausted');
      tx.set(ref,{start:same?old.start:now,count});
    });
  }
  async function catalogAvailable(tx,plan,labels=null) {
    for(const item of plan.values.ingredients??[]) if(item.catalogId!==null && item.catalogId!==undefined) {
      const food=await tx.get(store.doc('common/ingredients/items/'+item.catalogId));
      if(!food.exists) return false;
      if(labels) labels[item.catalogId]=String(food.data().name??item.catalogId).slice(0,200);
    }
    return true;
  }
  async function loadRows(tx,child,plan) {
    const rows=new Map();
    const add=async(kind,id)=>{
      const row=(await tx.get(root(child).collection('entities').doc(`${kind}_${id}`))).data();
      if(row) rows.set(`${kind}/${id}`,row);
      return row?.payload;
    };
    if(plan.type.endsWith('Meal')) {
      if(plan.type==='updateMeal') {
        await add('meals',plan.targetId);
        const children=await tx.get(root(child).collection('entities').where('payload.meal_id','==',plan.targetId).limit(251));
        if(children.docs.length>250) fail('resource-exhausted');
        for(const doc of children.docs) {
          const row=doc.data(); if(row.deleted || !['mealIngredients','mealHistory','mealSnapshots'].includes(row.kind)) continue;
          rows.set(`${row.kind}/${row.id}`,row);
          if(row.kind==='mealIngredients') {
            await add('ingredients',row.payload.ingredient_id);
            if(row.payload.portion_id) await add('portions',row.payload.portion_id);
          }
        }
      }
      for(const item of plan.values.ingredients) if(item.ingredientId!==null) await add('ingredients',item.ingredientId);
    } else if(plan.type==='planActivity') await add('activities',plan.values.activityId);
    else {
      const occurrence=await add('activityOccurrences',plan.targetId);
      if(occurrence) {
        await add('activities',occurrence.activity_id);
        if(occurrence.schedule_id) await add('activitySchedules',occurrence.schedule_id);
        if(occurrence.activity_log_id) await add('activityLogs',occurrence.activity_log_id);
      }
    }
    return [...rows.values()];
  }
  async function submit(uid, data) {
    validatePlan(data,false); await rate(uid,'submit',30);
    return store.runTransaction(async tx => {
      const {family,account} = await familyContext(store,tx,uid);
      if (account.role !== 'managingCaregiver') fail('permission-denied');
      const child = family.childUid;
      const state = (await tx.get(root(child))).data();
      if (state?.sourceId !== data.sourceId) fail('failed-precondition');
      const ref = operation(child,data.id);
      const existing = (await tx.get(ref)).data();
      const digest = hash(JSON.stringify(data));
      if (existing) {
        if (existing.authorUid !== uid || existing.digest !== digest) fail('already-exists');
        return {id:data.id,status:existing.status};
      }
      validatePlan(data);
      if((state.pendingPlans??0)>=50) fail('resource-exhausted');
      const key = data.type === 'updateMeal' ? `meal_${data.targetId}` : ['confirmActivity','moveActivity'].includes(data.type) ? `occurrence_${data.targetId}` : `new_${data.id}`;
      const locked = (await tx.get(lock(child,key))).data();
      if (locked?.operationId) fail('failed-precondition');
      const rows = await loadRows(tx,child,data);
      const guards=await tx.get(root(child).collection('entities').where('payload.active','==',1).limit(100));
      const occurrence=rows.find(r=>r.kind==='activityOccurrences'&&r.id===String(data.targetId))?.payload;
      const log=rows.find(r=>r.kind==='activityLogs'&&r.id===String(occurrence?.activity_log_id))?.payload;
      if(['moveActivity','confirmActivity'].includes(data.type)&&log&&(log.started_at<=Date.now()||log.ended_at!=null))fail('failed-precondition');
      const monitoring=guards.docs.some(doc=>{
        const row=doc.data();if(row.kind!=='workflowLocks'||row.deleted)return false;
        return data.type==='updateMeal'?row.payload.kind==='meal'&&row.payload.entity_id===data.targetId:
          ['moveActivity','confirmActivity'].includes(data.type)&&row.payload.kind==='activity'&&row.payload.entity_id===occurrence?.activity_log_id;
      });
      if(monitoring || (['moveActivity','confirmActivity'].includes(data.type)&&occurrence?.target_requested_at!=null))fail('failed-precondition');
      const catalogLabels={};
      if(!await catalogAvailable(tx,data,catalogLabels)) fail('failed-precondition');
      const base = scopeRows(rows,data);
      if (Buffer.byteLength(JSON.stringify(base)) > 65536) fail('resource-exhausted');
      if (JSON.stringify(versions(base)) !== JSON.stringify(versions(data.expected))) fail('failed-precondition');
      if (data.type === 'updateMeal') {
        const meal = base.find(row => row.kind === 'meals').payload;
        if (meal.status !== 'planned' || meal.purpose !== 'meal') fail('failed-precondition');
      }
      if (['confirmActivity','moveActivity'].includes(data.type)) {
        const occurrence = base.find(row => row.kind === 'activityOccurrences').payload;
        if (occurrence.started_at <= Date.now() || !(data.type === 'confirmActivity' ? ['pending'] : ['pending','planned']).includes(occurrence.status)) fail('failed-precondition');
      }
      tx.set(ref, {...data, catalogLabels,digest,authorUid:uid,lockKey:key,status:'pending',createdAt:Date.now(),base,canonical:[],reason:null});
      tx.set(lock(child,key),{operationId:data.id});
      tx.update(root(child),{pendingPlans:(state.pendingPlans??0)+1});
      // One metadata document per child; no caller-selected recipient.
      tx.set(store.doc(`familyPlanSignals/${child}`),{operationId:data.id,changedAt:Date.now()});
      return {id:data.id,status:'pending'};
    });
  }
  async function fetch(uid, data) {
    exact(data, []); await rate(uid,'fetch',120);
    return store.runTransaction(async tx => {
      const {family,account} = await familyContext(store,tx,uid);
      const query = root(family.childUid).collection('plans');
      const snapshot = await tx.get(account.role === 'child' ? query.where('status','==','pending').limit(50) : query.orderBy('createdAt','desc').limit(50));
      const plans=[];
      for(const doc of snapshot.docs) {
        const {digest,claimToken,claimUntil,...plan}=doc.data();
        if(account.role==='child') plan.authorActive=(await tx.get(store.doc(`families/${account.familyId}/members/${plan.authorUid}`))).data()?.role==='managingCaregiver';
        if(account.role==='child') plan.catalogAvailable=await catalogAvailable(tx,plan);
        plans.push(plan);
      }
      const state = (await tx.get(root(family.childUid))).data();
      return {ownerUid:family.childUid,sourceId:state?.sourceId??null,plans};
    });
  }
  async function claim(uid,data) {
    exact(data,['id','sourceId']); await rate(uid,'claim',60);
    if(typeof data.id!=='string'|| !/^[a-f0-9]{32}$/.test(data.id)) fail('invalid-argument');
    return store.runTransaction(async tx=>{
      const {account}=await familyContext(store,tx,uid,true);
      const state=(await tx.get(root(uid))).data();
      if(state?.sourceId!==data.sourceId) fail('failed-precondition');
      const ref=operation(uid,data.id); const plan=(await tx.get(ref)).data();
      if(!plan || plan.status!=='pending') fail('failed-precondition');
      const authorActive=(await tx.get(store.doc(`families/${account.familyId}/members/${plan.authorUid}`))).data()?.role==='managingCaregiver';
      const claimToken=plan.claimToken??require('node:crypto').randomBytes(16).toString('hex');
      const claimUntil=plan.claimUntil>Date.now()?plan.claimUntil:Date.now()+30000;
      const available=await catalogAvailable(tx,plan);
      tx.update(ref,{claimToken,claimUntil});
      const {digest,...safe}=plan;
      return {...safe,authorActive,catalogAvailable:available,claimToken,claimUntil};
    });
  }
  async function acknowledge(uid, data) {
    exact(data,['id','sourceId','outcome','reason','resultId','claimToken']); await rate(uid,'acknowledge',60);
    if (!/^[a-f0-9]{32}$/.test(data.id) || !['prepared','applied','rejected'].includes(data.outcome) || !['conflict','ineligible','author-disconnected',null].includes(data.reason) || (data.resultId !== null && (!Number.isSafeInteger(data.resultId)||data.resultId<1))) fail('invalid-argument');
    return store.runTransaction(async tx => {
      const {family} = await familyContext(store,tx,uid,true);
      const state = (await tx.get(root(uid))).data();
      if (state?.sourceId !== data.sourceId) fail('failed-precondition');
      const ref = operation(uid,data.id); const plan=(await tx.get(ref)).data();
      if (!plan || plan.sourceId !== data.sourceId) fail('not-found');
      if(plan.claimToken!==data.claimToken) fail('permission-denied');
      if (plan.status !== 'pending') return {id:data.id,status:plan.status};
      const held = (await tx.get(lock(uid,plan.lockKey))).data();
      if (held?.operationId !== data.id) fail('failed-precondition');
      const resultKind=plan.type.endsWith('Meal')?'meal':'occurrence';
      const aliasKey=data.resultId===null?null:`${resultKind}_${data.resultId}`;
      const alias=aliasKey===null?null:(await tx.get(lock(uid,aliasKey))).data();
      if(data.outcome==='prepared') {
        if(data.resultId===null || data.reason!==null || (alias?.operationId && alias.operationId!==data.id))fail('failed-precondition');
        if(plan.resultId!==undefined && plan.resultId!==data.resultId)fail('failed-precondition');
        tx.set(lock(uid,aliasKey),{operationId:data.id});
        tx.update(ref,{resultId:data.resultId,resultLockKey:aliasKey});
        return {id:data.id,status:'pending'};
      }
      if(data.outcome==='applied' && (plan.resultId!==data.resultId || alias?.operationId!==data.id))fail('failed-precondition');
      const resultLock=plan.resultLockKey && plan.resultLockKey!==plan.lockKey?store.doc(`userMirrors/${uid}/planLocks/${plan.resultLockKey}`):null;
      // ACK must not depend on the size of a later-growing aggregate.
      // Keep a bounded comparison; the full canonical projection is fetched separately.
      const canonical=[];let canonicalBytes=2;
      const append=row=>{
        if(!row || canonical.some(r=>r.kind===row.kind&&r.id===row.id))return;
        const bytes=Buffer.byteLength(JSON.stringify(row))+1;
        if(canonicalBytes+bytes<=65536){canonical.push(row);canonicalBytes+=bytes;}
      };
      const kind=plan.type.endsWith('Meal')?'meals':'activityOccurrences';
      for(const id of new Set([data.resultId,plan.targetId].filter(id=>id!==null))) {
        const row=(await tx.get(root(uid).collection('entities').doc(`${kind}_${id}`))).data();
        append(row);
        if(kind==='meals') {
          const children=await tx.get(root(uid).collection('entities').where('payload.meal_id','==',id).limit(31));
          for(const child of children.docs)append(child.data());
        }
      }
      for(const item of (plan.values.ingredients??[]).slice(0,10)) {
        if(item.ingredientId!==null) append((await tx.get(root(uid).collection('entities').doc(`ingredients_${item.ingredientId}`))).data());
      }
      tx.update(ref,{status:data.outcome,reason:data.reason,resultId:data.resultId,canonical,canonicalTruncated:true,completedAt:Date.now()});
      tx.delete(lock(uid,plan.lockKey));
      if(resultLock)tx.delete(resultLock);
      tx.update(root(uid),{pendingPlans:Math.max(0,(state.pendingPlans??0)-1)});
      for(const memberUid of family.memberUids) tx.set(store.doc(`familyPlanSignals/${memberUid}`),{operationId:data.id,changedAt:Date.now()});
      return {id:data.id,status:data.outcome};
    });
  }
  return {submit,fetch,claim,acknowledge};
}
module.exports={createPlanService};
