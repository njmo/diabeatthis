'use strict';
const {validateProtocol}=require('./plan_operations.cjs');
const {FamilyError, exact, hash} = require('./security.cjs');
const contract = require('./mirror_contract.json');
const fail = code => { throw new FamilyError(code); };
async function familyContext(store, tx, uid, childOnly = false) {
  const account = (await tx.get(store.doc(`familyAccounts/${uid}`))).data();
  if (!account?.familyId) fail('permission-denied');
  const family = (await tx.get(store.doc(`families/${account.familyId}`))).data();
  const member = (await tx.get(store.doc(`families/${account.familyId}/members/${uid}`))).data();
  if (!family || !member || member.role !== account.role || !family.memberUids.includes(uid)) fail('permission-denied');
  if (childOnly && (family.childUid !== uid || member.role !== 'child')) fail('permission-denied');
  return {account, family};
}
function validateRecord(record) {
  exact(record, ['kind', 'id', 'revision', 'deleted', 'payload']);
  const spec = contract[record.kind];
  if (!spec || typeof record.id !== 'string' || !/^[1-9][0-9]*(?:_[1-9][0-9]*)?$/.test(record.id) || record.id.length > 42 || !Number.isSafeInteger(record.revision) || record.revision < 1 || typeof record.deleted !== 'boolean') fail('invalid-argument');
  if (record.deleted) { if (record.payload !== null) fail('invalid-argument'); return; }
  const columns = record.kind === 'meals' && !Object.hasOwn(record.payload ?? {}, 'planned_day')
    ? spec.columns.filter(column => column !== 'planned_day')
    : spec.columns;
  exact(record.payload, columns);
  if (Object.keys(record.payload).length !== columns.length || spec.keys.map(k => String(record.payload[k])).join('_') !== record.id) fail('invalid-argument');
  for (const value of Object.values(record.payload)) {
    if (value !== null && !(typeof value === 'string' && value.length <= 32000) && !(typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= Number.MAX_SAFE_INTEGER)) fail('invalid-argument');
  }
  if (Buffer.byteLength(JSON.stringify(record.payload)) > 65536) fail('invalid-argument');
}
function source(value) { if (typeof value !== 'string' || !/^[a-f0-9]{32}$/.test(value)) fail('invalid-argument'); return value; }
function createMirrorService({store}) {
  const root = uid => store.doc(`userMirrors/${uid}`);
  async function rate(uid, action, limit) {
    const ref = store.doc(`familyRateLimits/${hash(uid + ':mirror:' + action)}`);
    await store.runTransaction(async tx => {
      const old = (await tx.get(ref)).data(), time = Date.now();
      const same = old && old.windowStart + 60000 > time;
      const count = same ? old.count + 1 : 1;
      if (count > limit) fail('resource-exhausted');
      tx.set(ref, {windowStart: same ? old.windowStart : time, count});
    });
  }
  async function register(uid, data) {
    exact(data, Object.hasOwn(data,'activityCommandsVersion') ? ['sourceId','activityCommandsVersion'] : ['sourceId']);
    validateProtocol(data);
    source(data.sourceId); await rate(uid, 'register', 20);
    return store.runTransaction(async tx => {
      const context=await familyContext(store, tx, uid, true);
      const existing = (await tx.get(root(uid))).data();
      if (existing && existing.sourceId !== data.sourceId) fail('failed-precondition');
      if (!existing) {
        tx.set(root(uid), {sourceId: data.sourceId, sequence: 0, activityCommandsVersion: data.activityCommandsVersion ?? 0});
        for(const memberUid of context.family.memberUids) tx.set(store.doc(`familyMirrorSignals/${memberUid}`),{ownerUid:uid,sourceId:data.sourceId,sequence:0});
      }
      if (existing) tx.update(root(uid), {activityCommandsVersion: data.activityCommandsVersion ?? 0});
      return {sourceId: data.sourceId};
    });
  }
  async function publish(uid, data) {
    exact(data, ['sourceId', 'records']); source(data.sourceId);
    if (!Array.isArray(data.records) || data.records.length < 1 || data.records.length > 25 || Buffer.byteLength(JSON.stringify(data)) > 262144) fail('invalid-argument');
    data.records.forEach(validateRecord);
    await rate(uid, 'publish', 120);
    if (new Set(data.records.map(r => `${r.kind}_${r.id}`)).size !== data.records.length) fail('invalid-argument');
    return store.runTransaction(async tx => {
      const context = await familyContext(store, tx, uid, true);
      const state = (await tx.get(root(uid))).data();
      if (!state || state.sourceId !== data.sourceId) fail('failed-precondition');
      const refs = data.records.map(r => root(uid).collection('entities').doc(`${r.kind}_${r.id}`));
      const previous = await Promise.all(refs.map(ref => tx.get(ref)));
      let sequence = state.sequence;
      for (let index = 0; index < data.records.length; index++) {
        const record = data.records[index], old = previous[index].data();
        const digest = hash(JSON.stringify(record));
        if (old && (old.revision > record.revision || (old.revision === record.revision && old.digest !== digest))) fail('failed-precondition');
        if (old?.revision === record.revision) continue;
        tx.set(refs[index], {...record, digest, sequence: ++sequence});
      }
      if (sequence !== state.sequence) {
        tx.update(root(uid), {sequence});
        for (const memberUid of context.family.memberUids) tx.set(store.doc(`familyMirrorSignals/${memberUid}`), {ownerUid: uid, sourceId: data.sourceId, sequence});
      }
      return {sourceId: data.sourceId, acknowledged: data.records.map(r => ({kind: r.kind, id: r.id, revision: r.revision})), sequence};
    });
  }
  async function fetch(uid, data) {
    exact(data, ['after']);
    if (!Number.isSafeInteger(data.after) || data.after < 0) fail('invalid-argument');
    await rate(uid, 'fetch', 120);
    return store.runTransaction(async tx => {
      const {family} = await familyContext(store, tx, uid);
      const state = (await tx.get(root(family.childUid))).data();
      if (!state) return {ownerUid: family.childUid, sourceId: null, records: [], cursor: 0, hasMore: false};
      const rows = await tx.get(root(family.childUid).collection('entities').where('sequence', '>', data.after).orderBy('sequence').limit(50));
      const records = rows.docs.map(doc => { const {digest, ...record} = doc.data(); return record; });
      return {ownerUid: family.childUid, sourceId: state.sourceId, records, cursor: records.at(-1)?.sequence ?? data.after, hasMore: records.length === 50};
    });
  }
  return {register, publish, fetch};
}
module.exports = {createMirrorService, familyContext, validateRecord};
