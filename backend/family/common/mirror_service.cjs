'use strict';
const {validateProtocol}=require('./plan_operations.cjs');
const {FamilyError, exact, hash} = require('./security.cjs');
const {words, ingredientSearchPrefixes, matchesIngredientWords} = require('./ingredient_mirror_search.cjs');
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
      return {sourceId: data.sourceId, quickLowTreatmentItems: true};
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
        const prefixes = record.kind === 'ingredients' && !record.deleted
          ? {ingredientSearchPrefixes: ingredientSearchPrefixes(record.payload)} : {};
        tx.set(refs[index], {...record, ...prefixes, digest, sequence: ++sequence});
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
      const records = rows.docs.map(doc => { const {digest, ingredientSearchPrefixes, ...record} = doc.data(); return record; });
      return {ownerUid: family.childUid, sourceId: state.sourceId, records, cursor: records.at(-1)?.sequence ?? data.after, hasMore: records.length === 50};
    });
  }
  async function searchIngredients(uid, data) {
    exact(data, ['query', 'ingredientId', 'quickFoods', 'quickFoodsEditor', 'ingredientDetailsId']);
    if (Object.hasOwn(data, 'quickFoodsEditor') || Object.hasOwn(data, 'ingredientDetailsId')) return quickTreatmentEditor(uid, data);
    if (Object.hasOwn(data, 'quickFoods')) return quickTreatmentFoods(uid, data);
    if (Object.hasOwn(data, 'ingredientId')) return ingredientPieceWeight(uid, data);
    exact(data, ['query']);
    if (typeof data.query !== 'string' || data.query.length > 120) fail('invalid-argument');
    const query = words(data.query);
    const longest = query.reduce((longest, word) => word.length > longest.length ? word : longest, '');
    if (longest.length < 2) fail('invalid-argument');
    const prefix = Array.from(longest).slice(0, 32).join('');
    await rate(uid, 'ingredient-search', 120);
    return store.runTransaction(async tx => {
      const {account, family} = await familyContext(store, tx, uid);
      if (account.role !== 'managingCaregiver') fail('permission-denied');
      const ownerUid = family.childUid;
      const candidates = root(ownerUid).collection('entities')
        .where('ingredientSearchPrefixes', 'array-contains', prefix).orderBy('__name__').limit(40);
      const records = [];
      let page = candidates;
      for (let i = 0; i < 10; i++) {
        const {docs} = await tx.get(page);
        for (const doc of docs) {
          const {kind, id, payload, deleted} = doc.data();
          if (kind === 'ingredients' && !deleted && matchesIngredientWords(payload, query)) {
            records.push({kind, id, payload});
            if (records.length === 20) return {ownerUid, records};
          }
        }
        if (docs.length < 40) return {ownerUid, records};
        page = candidates.startAfter(docs.at(-1).id);
      }
      if ((await tx.get(page.limit(1))).docs.length) fail('resource-exhausted');
      return {ownerUid, records};
    });
  }

  async function quickTreatmentEditor(uid, data) {
    const initial = Object.hasOwn(data, 'quickFoodsEditor');
    exact(data, [initial ? 'quickFoodsEditor' : 'ingredientDetailsId']);
    const ingredientId = data.ingredientDetailsId;
    if (initial ? data.quickFoodsEditor !== true : !Number.isSafeInteger(ingredientId) || ingredientId < 1) fail('invalid-argument');
    await rate(uid, 'ingredient-search', 120);
    return store.runTransaction(async tx => {
      const {account, family} = await familyContext(store, tx, uid);
      if (account.role !== 'managingCaregiver') fail('permission-denied');
      const ownerUid = family.childUid;
      const mirror = root(ownerUid);
      const state = (await tx.get(mirror)).data();
      if (!state?.sourceId || (state.activityCommandsVersion ?? 0) < 6) fail('failed-precondition');
      const entities = mirror.collection('entities');
      const rows = new Map();
      const add = row => {
        if (!row || row.deleted) return;
        const {kind, id, payload, revision} = row;
        rows.set(`${kind}/${id}`, {kind, id, payload, revision});
      };
      const read = async (kind, id) => add((await tx.get(entities.doc(`${kind}_${id}`))).data());
      if (initial) {
        const {docs} = await tx.get(entities.where('kind', '==', 'quickLowTreatmentItems')
          .where('deleted', '==', false).limit(13));
        if (docs.length === 13) fail('resource-exhausted');
        const dependencies = new Map();
        for (const doc of docs) {
          const row = doc.data();
          add(row);
          const {ingredient_id: ingredient, portion_id: portion} = row.payload;
          dependencies.set(`ingredients/${ingredient}`, ['ingredients', ingredient]);
          if (portion != null) {
            dependencies.set(`portions/${portion}`, ['portions', portion]);
            dependencies.set(`ingredientPortions/${ingredient}_${portion}`, ['ingredientPortions', `${ingredient}_${portion}`]);
          }
        }
        await Promise.all([...dependencies.values()].map(([kind, id]) => read(kind, id)));
      } else {
        await read('ingredients', ingredientId);
        if (!rows.size) fail('not-found');
        const {docs} = await tx.get(entities.where('kind', '==', 'ingredientPortions')
          .where('payload.ingredient_id', '==', ingredientId).where('deleted', '==', false).limit(101));
        if (docs.length === 101) fail('resource-exhausted');
        await Promise.all(docs.map(async doc => {
          const row = doc.data();
          add(row);
          await read('portions', row.payload.portion_id);
        }));
      }
      return {ownerUid, sourceId: state.sourceId, records: [...rows.values()]};
    });
  }
  async function quickTreatmentFoods(uid, data) {
    exact(data, ['quickFoods']);
    if (data.quickFoods !== true) fail('invalid-argument');
    await rate(uid, 'ingredient-search', 120);
    return store.runTransaction(async tx => {
      const {account, family} = await familyContext(store, tx, uid);
      if (account.role !== 'managingCaregiver') fail('permission-denied');
      const ownerUid = family.childUid;
      const state = (await tx.get(root(ownerUid))).data();
      const entities = root(ownerUid).collection('entities');
      const snapshot = await tx.get(entities.where('kind', '==', 'quickLowTreatmentItems')
        .where('deleted', '==', false).limit(12));
      const foods = await Promise.all(snapshot.docs.map(async doc => {
        const shortcut = doc.data().payload;
        if (!shortcut || !Number.isSafeInteger(shortcut.ingredient_id) || !(shortcut.amount > 0)) return null;
        const ingredient = (await tx.get(entities.doc(`ingredients_${shortcut.ingredient_id}`))).data();
        if (!ingredient || ingredient.deleted) return null;
        let gramsPerUnit = ingredient.payload.is_reference === 1 ? null : 1;
        if (Number.isSafeInteger(shortcut.portion_id)) {
          const link = (await tx.get(entities.doc(`ingredientPortions_${shortcut.ingredient_id}_${shortcut.portion_id}`))).data();
          gramsPerUnit = link?.payload?.grams_per_portion;
          if (link?.deleted || !(gramsPerUnit > 0)) return null;
        }
        const amount = Number.isSafeInteger(shortcut.portion_id) || gramsPerUnit == null ? shortcut.amount : 1;
        if (amount === 1 && shortcut.portion_id == null && gramsPerUnit != null) gramsPerUnit = shortcut.amount;
        return {name: shortcut.name, order: shortcut.sort_order, amount, gramsPerUnit, ingredient: {id: ingredient.id, payload: ingredient.payload}};
      }));
      return {ownerUid, canEdit: (state?.activityCommandsVersion ?? 0) >= 6, foods: foods.filter(Boolean).sort((a, b) => a.order - b.order)};
    });
  }
  async function ingredientPieceWeight(uid, data) {
    exact(data, ['ingredientId']);
    if (!Number.isSafeInteger(data.ingredientId) || data.ingredientId < 1) fail('invalid-argument');
    await rate(uid, 'ingredient-search', 120);
    return store.runTransaction(async tx => {
      const {account, family} = await familyContext(store, tx, uid);
      if (account.role !== 'managingCaregiver') fail('permission-denied');
      const ownerUid = family.childUid;
      const entities = root(ownerUid).collection('entities');
      const ingredient = (await tx.get(entities.doc(`ingredients_${data.ingredientId}`))).data();
      if (!ingredient || ingredient.deleted) return {ownerUid, gramsPerPiece: null};
      const links = await tx.get(entities.where('kind', '==', 'ingredientPortions')
        .where('payload.ingredient_id', '==', data.ingredientId).limit(30));
      if (links.docs.length === 30) return {ownerUid, gramsPerPiece: null};
      const portions = await Promise.all(links.docs.map(async doc => {
        const link = doc.data().payload;
        if (!link || !Number.isSafeInteger(link.portion_id) || !(link.grams_per_portion > 0)) return null;
        const portion = (await tx.get(entities.doc(`portions_${link.portion_id}`))).data();
        if (!portion || portion.deleted) return null;
        const name = words(portion.payload?.name).join(' ');
        return ['szt', 'sztuka', 'piece', 'pc'].includes(name) ? link.grams_per_portion : null;
      }));
      const weights = new Set(portions.filter(weight => typeof weight === 'number' && Number.isFinite(weight)));
      return {ownerUid, gramsPerPiece: weights.size === 1 ? [...weights][0] : null};
    });
  }
  return {register, publish, fetch, searchIngredients};
}
module.exports = {createMirrorService, familyContext, validateRecord};
