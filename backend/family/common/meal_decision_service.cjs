'use strict';
const {randomBytes} = require('node:crypto');
const {FamilyError, exact, hash} = require('./security.cjs');
const {familyContext} = require('./mirror_service.cjs');
const fail = code => { throw new FamilyError(code); };
const token = value => typeof value === 'string' && /^[a-f0-9]{32}$/.test(value);
const mealId = value => typeof value === 'string' && /^[1-9][0-9]{0,20}$/.test(value);
const types = ['insulinThenWait', 'insulinAndEat', 'eatThenInsulin', 'deferMeal'];
function decision(value) {
  exact(value, ['type', 'minutes', 'message', 'targetSuggestion']);
  if (!types.includes(value.type) || !(value.minutes === null || (Number.isInteger(value.minutes) && value.minutes >= 1 && value.minutes <= 180)) || (['insulinThenWait','deferMeal'].includes(value.type) && value.minutes === null) || typeof value.message !== 'string' || value.message.length > 240 || !(value.targetSuggestion === null || (typeof value.targetSuggestion === 'string' && value.targetSuggestion.length <= 240))) fail('invalid-argument');
  return value;
}
function outcome(value, kind) {
  exact(value, ['source', 'decision', 'minutes', 'caregiverUid']);
  if (!(kind === 'accepted' ? value.source === 'caregiver' && typeof value.caregiverUid === 'string' : ['mealAdvisor','manual'].includes(value.source) && value.caregiverUid === null) || !types.includes(value.decision) || !(value.minutes === null || (Number.isInteger(value.minutes) && value.minutes >= 1 && value.minutes <= 180)) || (['insulinThenWait','deferMeal'].includes(value.decision) && value.minutes === null)) fail('invalid-argument');
  return value;
}
function createMealDecisionService({store, now = Date.now}) {
  const mirror = uid => store.doc(`userMirrors/${uid}`);
  const ref = (uid, requestId) => mirror(uid).collection('mealDecisions').doc(requestId);
  const pref = uid => store.doc(`familyMealDecisionPreferences/${uid}`);
  async function roster(tx, familyId, family) {
    const result = [];
    for (const uid of family.memberUids) {
      if (uid === family.childUid) continue;
      const member = (await tx.get(store.doc(`families/${familyId}/members/${uid}`))).data();
      const account = (await tx.get(store.doc(`familyAccounts/${uid}`))).data();
      const preference = (await tx.get(pref(uid))).data();
      if (member?.role === 'managingCaregiver' && family.managerUids?.includes(uid) && account?.role === member.role && account.familyId === familyId) result.push({uid, displayName: member.displayName || '', enabled: preference?.enabled === true});
    }
    return result;
  }
  function signal(tx, members, requestId, time) {
    for (const uid of members) tx.set(store.doc(`familyMealDecisionSignals/${uid}`), {requestId, changedAt: time});
  }
  function notify(tx, childUid, recipientUid, requestId, time, reason) {
    const jobId = hash(`${childUid}:${recipientUid}:${requestId}:${reason}:${time}`);
    tx.set(store.doc(`familyMealDecisionNotifications/${jobId}`), {childUid, recipientUid, requestId, createdAt: time, kind:reason === 'response' ? 'response' : 'request'});
  }
  async function rate(uid, action) {
    const r = store.doc(`familyRateLimits/${hash(`${uid}:mealDecision:${action}`)}`);
    await store.runTransaction(async tx => {
      const old = (await tx.get(r)).data(), time = now(), same = old && old.start + 60000 > time;
      const count = same ? old.count + 1 : 1;
      if (count > 120) fail('resource-exhausted');
      tx.set(r, {start: same ? old.start : time, count});
    });
  }
  async function execute(uid, input) {
    exact(input, ['action', 'enabled', 'requestId', 'mealId', 'sourceId', 'caregiverUid', 'decision', 'outcome', 'stage', 'present', 'timeoutFallback', 'acceptanceToken', 'allowManualDecision']);
    const {action} = input;
    const schemas = {configure:['action','enabled'], create:Object.hasOwn(input,'allowManualDecision') ? ['action','requestId','mealId','sourceId','timeoutFallback','allowManualDecision'] : ['action','requestId','mealId','sourceId','timeoutFallback'], fetch:['action'], claim:['action','requestId'], heartbeat:['action','requestId','stage','present'], decline:['action','requestId'], delegate:['action','requestId','caregiverUid'], respond:['action','requestId','decision'], prepareAcceptance:['action','requestId','sourceId'], abortAcceptance:['action','requestId','sourceId','acceptanceToken'], acknowledge:['action','requestId','sourceId','acceptanceToken','outcome'], expire:Object.hasOwn(input,'acceptanceToken') ? ['action','requestId','sourceId','outcome','acceptanceToken'] : ['action','requestId','sourceId','outcome']};
    if (!Object.hasOwn(schemas, action)) fail('invalid-argument');
    exact(input, schemas[action]);
    if (Object.keys(input).length !== schemas[action].length) fail('invalid-argument');
    if (action === 'configure' && typeof input.enabled !== 'boolean') fail('invalid-argument');
    if (action !== 'configure' && action !== 'fetch' && !token(input.requestId)) fail('invalid-argument');
    if (action === 'create' && (!mealId(input.mealId) || !token(input.sourceId) || !['app','manual'].includes(input.timeoutFallback) || (Object.hasOwn(input,'allowManualDecision') && typeof input.allowManualDecision !== 'boolean') || (input.timeoutFallback === 'manual' && input.allowManualDecision === false))) fail('invalid-argument');
    if (['prepareAcceptance','abortAcceptance','acknowledge','expire'].includes(action) && !token(input.sourceId)) fail('invalid-argument');
    if (action === 'delegate' && (typeof input.caregiverUid !== 'string' || !input.caregiverUid || input.caregiverUid.includes('/') || input.caregiverUid.length > 128)) fail('invalid-argument');
    if (action === 'heartbeat' && (!['context','decision'].includes(input.stage) || typeof input.present !== 'boolean')) fail('invalid-argument');
    if (action === 'respond') decision(input.decision);
    if (action === 'abortAcceptance' && !token(input.acceptanceToken)) fail('invalid-argument');
    if (action === 'acknowledge') { if (!token(input.acceptanceToken)) fail('invalid-argument'); outcome(input.outcome, 'accepted'); }
    if (action === 'expire') { if (Object.hasOwn(input,'acceptanceToken') && !token(input.acceptanceToken)) fail('invalid-argument'); outcome(input.outcome, 'fallback'); }
    await rate(uid, action);
    return store.runTransaction(async tx => {
      const {family, account} = await familyContext(store, tx, uid);
      const child = family.childUid, time = now();
      const isChild = account.role === 'child' && uid === child;
      const isCaregiver = account.role === 'managingCaregiver';
      if (!isChild && !isCaregiver) fail('permission-denied');
      if (action === 'configure') {
        if (!isCaregiver || !family.managerUids?.includes(uid)) fail('permission-denied');
        tx.set(pref(uid), {enabled: input.enabled});
        signal(tx, family.memberUids, null, time);
        return {enabled: input.enabled};
      }
      const state = (await tx.get(mirror(child))).data();
      const caregivers = await roster(tx, account.familyId, family);
      const me = caregivers.find(c => c.uid === uid);
      if (isCaregiver && !me) fail('permission-denied');
      if (action === 'fetch') {
        const rows = await tx.get(mirror(child).collection('mealDecisions').orderBy('createdAt','desc').limit(50));
        const requests = rows.docs.filter(doc => doc.data().familyId === account.familyId).map(doc => {
          const row = doc.data();
          const accepting = row.status === 'responded' && Boolean(row.acceptanceToken);
          const expired = ['open','responded'].includes(row.status) && row.deadline <= time && !accepting;
          const owner = caregivers.find(c => c.uid === row.ownerUid && c.enabled);
          const claimedByUid = owner ? row.ownerUid : null;
          const claimAvailable = row.status === 'open' && row.deadline > time && (!owner || !(row.claimUntil > time));
          const {acceptanceToken, abortedTokenHash, ...safe} = row;
          return {...safe, id:row.requestId, ownerUid:child, status:expired ? 'expired' : accepting ? 'accepting' : ({open:'waiting',responded:'answered',acknowledged:'accepted',expired:'expired'}[row.status]), claimedByUid, claimedByName:claimedByUid ? owner.displayName : null, claimAvailable, presentUntil:claimedByUid ? (row.presentUntil ?? 0) : null, stage:claimedByUid ? row.stage : null, members:caregivers.map(c => ({...c,status:row.declinedUids.includes(c.uid) ? 'declined' : claimedByUid === c.uid ? 'claimed' : c.enabled ? 'available' : 'disabled'}))};
        });
        return {ownerUid: child, sourceId: state?.sourceId ?? null, requests, caregivers, enabled: me?.enabled ?? null};
      }
      if (action === 'create') {
        if (!isChild) fail('permission-denied');
        if (state?.sourceId !== input.sourceId) fail('failed-precondition');
        const existing = (await tx.get(ref(child, input.requestId))).data();
        if (existing) {
          if (existing.mealId !== input.mealId || existing.sourceId !== input.sourceId || existing.familyId !== account.familyId || existing.timeoutFallback !== input.timeoutFallback || (existing.allowManualDecision ?? true) !== (input.allowManualDecision ?? true)) fail('already-exists');
          return existing;
        }
        const slotRef = mirror(child).collection('mealDecisionSlots').doc(`${input.sourceId}_${input.mealId}`);
        const slot = (await tx.get(slotRef)).data();
        const previous = slot?.requestId ? (await tx.get(ref(child,slot.requestId))).data() : null;
        const active = previous && previous.familyId === account.familyId && previous.childUid === child && previous.sourceId === input.sourceId && previous.mealId === input.mealId && (previous.status === 'open' && previous.deadline > time || previous.status === 'responded' && (previous.deadline > time || previous.acceptanceToken));
        if (active) return previous;
        const meal = (await tx.get(mirror(child).collection('entities').doc(`meals_${input.mealId}`))).data();
        if (!meal || meal.deleted || meal.kind !== 'meals' || meal.payload?.status !== 'planned' || meal.payload?.purpose !== 'meal') fail('failed-precondition');
        const row = {requestId:input.requestId, familyId:account.familyId, childUid:child, sourceId:input.sourceId, mealId:input.mealId, mealRevision:meal.revision, mealName:String(meal.payload.name ?? '').slice(0,120), timeoutFallback:input.timeoutFallback, allowManualDecision:input.allowManualDecision ?? true, createdAt:time, deadline:time+300000, status:'open', ownerUid:null, claimUntil:null, presentUntil:null, stage:null, declinedUids:[], response:null, outcome:null};
        tx.set(ref(child,input.requestId),row);
        tx.set(slotRef,{requestId:input.requestId});
        signal(tx,family.memberUids,input.requestId,time);
        for (const caregiver of caregivers.filter(c => c.enabled)) notify(tx,child,caregiver.uid,input.requestId,time,'create');
        return row;
      }
      const recordRef = ref(child,input.requestId);
      const row = (await tx.get(recordRef)).data();
      if (!row || row.familyId !== account.familyId || row.childUid !== child) fail('not-found');
      if (['prepareAcceptance','abortAcceptance','acknowledge','expire'].includes(action)) {
        if (!isChild) fail('permission-denied');
        if (row.sourceId !== input.sourceId || (!['acknowledge','abortAcceptance'].includes(action) && !(action === 'prepareAcceptance' && row.acceptanceToken) && state?.sourceId !== input.sourceId)) fail('failed-precondition');
        if (action === 'prepareAcceptance') {
          if (row.status === 'responded' && row.acceptanceToken) return {requestId:input.requestId,acceptanceToken:row.acceptanceToken,acceptanceUntil:row.acceptanceUntil};
          if (row.status !== 'responded' || row.deadline <= time || !caregivers.some(c => c.uid === row.response?.caregiverUid && c.enabled)) fail('failed-precondition');
          const meal = (await tx.get(mirror(child).collection('entities').doc(`meals_${row.mealId}`))).data();
          if (!meal || meal.deleted || meal.revision !== row.mealRevision || meal.payload?.status !== 'planned' || meal.payload?.purpose !== 'meal') fail('failed-precondition');
          const acceptanceToken = randomBytes(16).toString('hex');
          const acceptanceUntil = time + 60000;
          tx.update(recordRef,{acceptanceToken,acceptanceUntil});
          signal(tx,family.memberUids,input.requestId,time);
          return {requestId:input.requestId,acceptanceToken,acceptanceUntil};
        }
        if (action === 'abortAcceptance') {
          if (row.status === 'expired' && row.acceptanceAborted === true && row.abortedTokenHash === hash(input.acceptanceToken)) return {requestId:input.requestId,status:'expired'};
          if (!row.acceptanceToken || row.acceptanceToken !== input.acceptanceToken) fail('permission-denied');
          if (row.status !== 'responded') fail('failed-precondition');
          tx.update(recordRef,{status:'expired',acceptanceAborted:true,abortedTokenHash:hash(input.acceptanceToken),acceptanceToken:null,outcome:null,completedAt:time});
          signal(tx,family.memberUids,input.requestId,time);
          return {requestId:input.requestId,status:'expired'};
        }
        const target = action === 'acknowledge' ? 'acknowledged' : 'expired';
        if (action === 'acknowledge' && row.acceptanceToken !== input.acceptanceToken) fail('permission-denied');
        if (action === 'expire' && row.acceptanceToken) fail('failed-precondition');
        if (row.status === target && row.outcome !== null && JSON.stringify(row.outcome) === JSON.stringify(input.outcome)) return row;
        if (action === 'acknowledge' ? row.status !== 'responded' : row.deadline > time || !(row.status === 'expired' && row.acceptanceAborted === true && row.outcome === null) && !['open','responded'].includes(row.status)) fail('failed-precondition');
        if (action === 'acknowledge' && (input.outcome.caregiverUid !== row.response?.caregiverUid || input.outcome.decision !== row.response?.type || input.outcome.minutes !== row.response?.minutes)) fail('failed-precondition');
        if (action === 'expire' && input.outcome.source === 'manual' && row.allowManualDecision === false) fail('failed-precondition');
        const updated = {...row,status:target,outcome:input.outcome,completedAt:time};
        tx.set(recordRef,updated); signal(tx,family.memberUids,input.requestId,time); return updated;
      }
      if (!isCaregiver || !me.enabled) fail('permission-denied');
      if (row.status !== 'open' || row.deadline <= time) fail('failed-precondition');
      if (row.declinedUids.includes(uid)) fail('failed-precondition');
      const currentOwner = caregivers.find(c => c.uid === row.ownerUid && c.enabled);
      const activeOwner = currentOwner && row.claimUntil > time ? row.ownerUid : null;
      const patch = {};
      if (action === 'claim') {
        if (activeOwner && activeOwner !== uid) fail('failed-precondition');
        Object.assign(patch,{ownerUid:uid,claimUntil:time+30000,presentUntil:time+30000,stage:'context'});
      } else if (action === 'heartbeat') {
        if (row.ownerUid !== uid) fail('failed-precondition');
        Object.assign(patch,input.present ? {claimUntil:time+30000,presentUntil:time+30000,stage:input.stage} : {presentUntil:0,stage:input.stage});
      } else if (action === 'decline') {
        Object.assign(patch,{declinedUids:[...row.declinedUids,uid],...(row.ownerUid === uid ? {ownerUid:null,claimUntil:null,presentUntil:null,stage:null} : {})});
      } else if (action === 'delegate') {
        if (activeOwner !== uid) fail('failed-precondition');
        const target = caregivers.find(c => c.uid === input.caregiverUid && c.enabled);
        if (!target || target.uid === uid || row.declinedUids.includes(target.uid)) fail('failed-precondition');
        Object.assign(patch,{ownerUid:target.uid,claimUntil:time+30000,presentUntil:0,stage:'context'});
      } else if (action === 'respond') {
        if (activeOwner !== uid || state?.sourceId !== row.sourceId) fail('failed-precondition');
        const meal = (await tx.get(mirror(child).collection('entities').doc(`meals_${row.mealId}`))).data();
        if (!meal || meal.deleted || meal.revision !== row.mealRevision || meal.payload?.status !== 'planned' || meal.payload?.purpose !== 'meal') fail('failed-precondition');
        Object.assign(patch,{status:'responded',response:{...input.decision,caregiverUid:uid,caregiverName:me.displayName,respondedAt:time},stage:'decision',claimUntil:null,presentUntil:null});
      } else fail('invalid-argument');
      const updated = {...row,...patch};
      tx.set(recordRef,updated); signal(tx,family.memberUids,input.requestId,time);
      if (action === 'delegate') notify(tx,child,input.caregiverUid,input.requestId,time,'delegate');
      if (action === 'respond') notify(tx,child,child,input.requestId,time,'response');
      return updated;
    });
  }
  return {execute};
}
module.exports = {createMealDecisionService};
