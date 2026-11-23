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
  const meal = record.kind === 'meals';
  const hasAddOnProgress = meal && Object.hasOwn(record.payload ?? {}, 'add_on_progress');
  const hasTreatmentSurplus = meal && Object.hasOwn(record.payload ?? {}, 'treatment_surplus');
  const columns = [
    ...spec.columns.filter(column => !meal || column !== 'planned_day' || Object.hasOwn(record.payload ?? {}, column)),
    ...(hasAddOnProgress ? ['add_on_progress'] : []),
    ...(hasTreatmentSurplus ? ['treatment_surplus'] : []),
  ];
  exact(record.payload, columns);
  if (Object.keys(record.payload).length !== columns.length || spec.keys.map(k => String(record.payload[k])).join('_') !== record.id) fail('invalid-argument');
  if (hasTreatmentSurplus && record.payload.treatment_surplus !== 1) fail('invalid-argument');
  if (hasAddOnProgress) {
    const value = record.payload.add_on_progress;
    if (typeof value !== 'string' || value.length > 256 ||
        !['eating-extra', 'waiting-for-bolus'].includes(record.payload.status)) fail('invalid-argument');
    let progress;
    try { progress = JSON.parse(value); } catch (_) { fail('invalid-argument'); }
    const fields = ['originalStatus', 'awaitingBolus', 'additionalServing', 'bolusBeforeExtra'];
    exact(progress, fields);
    if (Object.keys(progress).length !== fields.length ||
        typeof progress.originalStatus !== 'string' || !/^[a-z-]{1,32}$/.test(progress.originalStatus) ||
        ![0, 1].includes(progress.awaitingBolus) ||
        ![null, 0, 1].includes(progress.additionalServing) ||
        ![0, 1].includes(progress.bolusBeforeExtra)) fail('invalid-argument');
  }
  for (const value of Object.values(record.payload)) {
    if (value !== null && !(typeof value === 'string' && value.length <= 32000) && !(typeof value === 'number' && Number.isFinite(value) && Math.abs(value) <= Number.MAX_SAFE_INTEGER)) fail('invalid-argument');
  }
  if (Buffer.byteLength(JSON.stringify(record.payload)) > 65536) fail('invalid-argument');
}
function source(value) { if (typeof value !== 'string' || !/^[a-f0-9]{32}$/.test(value)) fail('invalid-argument'); return value; }
const mealHeaderFields = ['id', 'name', 'status', 'category', 'purpose', 'planned_at', 'planned_day', 'created_at'];
const mealCategories = new Set(['breakfast', 'secondBreakfast', 'lunch', 'snack', 'afternoonSnack', 'dinner']);
const mealHeaderPageSize = 10;
const mealHeaderScanLimit = 64;

function mealHeader(record) {
  if (!record || record.deleted || !Number.isSafeInteger(record.payload?.id) ||
      String(record.payload.id) !== record.id) return null;
  const payload = Object.fromEntries(mealHeaderFields.map(key => [key, record.payload[key] ?? null]));
  const day = typeof payload.planned_day === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(payload.planned_day)
    ? Date.parse(payload.planned_day) : NaN;
  const plannedDay = Number.isFinite(day) && new Date(day).toISOString().slice(0, 10) === payload.planned_day
    ? day : null;
  const time = [payload.planned_at, plannedDay, payload.created_at].find(Number.isSafeInteger) ?? 0;
  // A fixed-width composite gives Firestore a single ordered field with a numeric ID tiebreaker.
  const shiftedTime = (BigInt(time) + BigInt(Number.MAX_SAFE_INTEGER)).toString().padStart(17, '0');
  const sortKey = `${shiftedTime}:${record.id.padStart(16, '0')}`;
  return {sortKey, category: payload.category, record: {kind: 'meals', id: record.id, payload}};
}

function writeMealHeader(tx, mirror, record, header = mealHeader(record)) {
  const ref = mirror.collection('mealHeaders').doc(record.id);
  if (header) tx.set(ref, header);
  else tx.delete(ref);
}

function readMealHeaderCursor(value) {
  if (value === null) return null;
  let cursor;
  if (typeof value === 'string' && /^[\w-]{1,256}$/.test(value)) {
    try { cursor = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')); } catch (_) { /* invalid cursor */ }
  }
  if (!Array.isArray(cursor) || cursor.length !== 3 ||
      typeof cursor[0] !== 'string' || !/^[a-f0-9]{64}$/.test(cursor[0]) ||
      !Number.isSafeInteger(cursor[1]) || cursor[1] < 0 ||
      (cursor[2] !== null && (typeof cursor[2] !== 'string' || !/^\d{17}:\d{16}$/.test(cursor[2])))) fail('invalid-argument');
  return cursor;
}

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
    exact(data, ['sourceId', 'activityCommandsVersion', 'mealHeadersExportVersion']);
    validateProtocol(data);
    const supportsHeaderExport = Object.hasOwn(data, 'mealHeadersExportVersion');
    if (supportsHeaderExport && data.mealHeadersExportVersion !== 1) fail('invalid-argument');
    source(data.sourceId); await rate(uid, 'register', 20);
    return store.runTransaction(async tx => {
      const context=await familyContext(store, tx, uid, true);
      const existing = (await tx.get(root(uid))).data();
      if (existing && existing.sourceId !== data.sourceId) fail('failed-precondition');
      const exportComplete = existing?.mealHeadersExportComplete === true;
      // Only clients that advertise this capability can confirm their initial export.
      const exportPending = supportsHeaderExport && !exportComplete;
      const pendingChanged = exportPending !== (existing?.mealHeadersExportPending === true);
      const revision = (existing?.mealHeadersRevision ?? 0) + (pendingChanged ? 1 : 0);
      const state = {activityCommandsVersion: data.activityCommandsVersion ?? 0};
      if (!existing) {
        tx.set(root(uid), {sourceId: data.sourceId, sequence: 0, ...state,
          mealHeadersBackfillAfter: null, mealHeadersRevision: revision, mealHeadersExportPending: exportPending});
      } else {
        tx.update(root(uid), pendingChanged
          ? {...state, mealHeadersRevision: revision, mealHeadersExportPending: exportPending} : state);
      }
      if (!existing || pendingChanged) {
        for (const memberUid of context.family.memberUids) {
          tx.set(store.doc(`familyMirrorSignals/${memberUid}`), {ownerUid: uid, sourceId: data.sourceId,
            sequence: existing?.sequence ?? 0, mealHeadersRevision: revision});
        }
      }
      return {sourceId: data.sourceId, quickLowTreatmentItems: true,
        ...(supportsHeaderExport ? {mealHeadersExportComplete: exportComplete} : {})};
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
      let mealHeadersChanged = false;
      for (let index = 0; index < data.records.length; index++) {
        const record = data.records[index], old = previous[index].data();
        const digest = hash(JSON.stringify(record));
        if (old && (old.revision > record.revision || (old.revision === record.revision && old.digest !== digest))) fail('failed-precondition');
        if (old?.revision === record.revision) continue;
        const prefixes = record.kind === 'ingredients' && !record.deleted
          ? {ingredientSearchPrefixes: ingredientSearchPrefixes(record.payload)} : {};
        tx.set(refs[index], {...record, ...prefixes, digest, sequence: ++sequence});
        if (record.kind === 'meals') {
          const header = mealHeader(record);
          const changed = JSON.stringify(header) !== JSON.stringify(mealHeader(old));
          if (changed || state.mealHeadersBackfillAfter !== null) writeMealHeader(tx, root(uid), record, header);
          mealHeadersChanged ||= changed;
        }
      }
      if (sequence !== state.sequence) {
        const mealHeadersRevision = (state.mealHeadersRevision ?? 0) + (mealHeadersChanged ? 1 : 0);
        tx.update(root(uid), {sequence, mealHeadersRevision});
        for (const memberUid of context.family.memberUids) tx.set(store.doc(`familyMirrorSignals/${memberUid}`), {ownerUid: uid, sourceId: data.sourceId, sequence, mealHeadersRevision});
      }
      return {sourceId: data.sourceId, acknowledged: data.records.map(r => ({kind: r.kind, id: r.id, revision: r.revision})), sequence};
    });
  }
  async function completeMealHeaderExport(uid, data) {
    exact(data, ['sourceId']);
    const sourceId = source(data.sourceId);
    await rate(uid, 'meal-headers-complete', 20);
    return store.runTransaction(async tx => {
      const {family} = await familyContext(store, tx, uid, true);
      const mirror = root(uid);
      const state = (await tx.get(mirror)).data();
      if (state?.sourceId !== sourceId) fail('failed-precondition');
      const sequence = state.sequence;
      let mealHeadersRevision = state.mealHeadersRevision ?? 0;
      if (state.mealHeadersExportComplete !== true) {
        mealHeadersRevision++;
        tx.update(mirror, {mealHeadersExportComplete: true, mealHeadersExportPending: false, mealHeadersRevision});
        for (const memberUid of family.memberUids) {
          tx.set(store.doc(`familyMirrorSignals/${memberUid}`), {ownerUid: uid, sourceId, sequence, mealHeadersRevision});
        }
      }
      return {sourceId, sequence, mealHeadersRevision};
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
  async function fetchMealHeaders(uid, data) {
    exact(data, ['query', 'category', 'cursor']);
    if (typeof data.query !== 'string' || data.query.length > 120 ||
        (data.category !== null && !mealCategories.has(data.category))) fail('invalid-argument');
    const cursor = readMealHeaderCursor(data.cursor);
    const query = data.query.trim().toLowerCase();
    await rate(uid, 'meal-headers', 120);
    return store.runTransaction(async tx => {
      const {account, family} = await familyContext(store, tx, uid);
      const ownerUid = family.childUid;
      const mirror = root(ownerUid);
      const state = (await tx.get(mirror)).data();
      const sourceId = state?.sourceId ?? null;
      const sequence = state?.sequence ?? 0;
      const records = [];
      const mealHeadersRevision = state?.mealHeadersRevision ?? 0;
      const initialHeadersComplete = state?.mealHeadersBackfillAfter === null && state.mealHeadersExportPending !== true;
      const page = {ownerUid, sourceId, sequence, mealHeadersRevision, records, nextCursor: null, initialHeadersComplete};
      const binding = hash(JSON.stringify([uid, account.familyId, ownerUid, sourceId, query, data.category]));
      const encodeCursor = key => Buffer.from(JSON.stringify([binding, mealHeadersRevision, key])).toString('base64url');
      if (cursor && (cursor[0] !== binding || (cursor[2] !== null && cursor[1] !== mealHeadersRevision))) {
        fail('failed-precondition');
      }
      if (!state) return page;

      // Backfill legacy mirrors in bounded transactions. Publish uses the same root and entity
      // transactions, so a concurrent update or deletion cannot be overwritten by this scan.
      if (state.mealHeadersBackfillAfter !== null) {
        let legacy = mirror.collection('entities').where('kind', '==', 'meals')
          .orderBy('__name__').select('id', 'deleted', ...mealHeaderFields.map(key => `payload.${key}`))
          .limit(mealHeaderScanLimit);
        if (state.mealHeadersBackfillAfter) legacy = legacy.startAfter(state.mealHeadersBackfillAfter);
        const {docs} = await tx.get(legacy);
        for (const doc of docs) writeMealHeader(tx, mirror, doc.data());
        const after = docs.length === mealHeaderScanLimit ? docs.at(-1).id : null;
        tx.update(mirror, {mealHeadersBackfillAfter: after});
        return {...page, nextCursor: encodeCursor(null)};
      }

      let headers = mirror.collection('mealHeaders');
      if (data.category !== null) headers = headers.where('category', '==', data.category);
      headers = headers.orderBy('sortKey', 'desc');
      if (cursor?.[2] != null) headers = headers.startAfter(cursor[2]);
      const limit = query ? mealHeaderScanLimit : mealHeaderPageSize;
      const {docs} = await tx.get(headers.limit(limit + 1));
      for (let i = 0; i < Math.min(limit, docs.length); i++) {
        const {sortKey, record} = docs[i].data();
        if (String(record.payload.name ?? '').toLowerCase().includes(query)) records.push(record);
        if (records.length === mealHeaderPageSize || i + 1 === limit) {
          if (docs.length > i + 1) page.nextCursor = encodeCursor(sortKey);
          break;
        }
      }
      return page;
    });
  }
  async function fetchMealProgress(uid, data) {
    exact(data, ['mealId']);
    if (!Number.isSafeInteger(data.mealId) || data.mealId < 1) fail('invalid-argument');
    await rate(uid, 'meal-progress', 120);
    return store.runTransaction(async tx => {
      const {family} = await familyContext(store, tx, uid);
      const ownerUid = family.childUid;
      const mirror = root(ownerUid);
      const state = (await tx.get(mirror)).data();
      if (!state) return {ownerUid, sourceId: null, sequence: 0, records: []};
      const entries = await tx.get(mirror.collection('entities')
        .where('kind', '==', 'mealHistory')
        .where('payload.meal_id', '==', data.mealId)
        .select('kind', 'id', 'deleted', 'payload.meal_id', 'payload.status', 'payload.created_at')
        .limit(201));
      if (entries.docs.length > 200) fail('resource-exhausted');
      const records = entries.docs.map(doc => doc.data()).filter(record => !record.deleted);
      return {ownerUid, sourceId: state.sourceId, sequence: state.sequence, records};
    });
  }
  async function fetchView(uid, data) {
    const home = data?.view === 'home';
    exact(data, home ? ['view', 'date', 'startMs', 'endMs'] : ['view', 'mealId', 'context']);
    const hour = 3600000;
    if (home) {
      if (typeof data.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(data.date) ||
          !Number.isSafeInteger(data.startMs) || !Number.isSafeInteger(data.endMs) ||
          data.endMs <= data.startMs || data.endMs - data.startMs > 26 * hour ||
          Math.abs(Date.now() - data.startMs) > 48 * hour) fail('invalid-argument');
    } else if (data.view !== 'meal' || !Number.isSafeInteger(data.mealId) ||
               data.mealId < 1 || typeof data.context !== 'boolean') {
      fail('invalid-argument');
    }
    await rate(uid, 'view', 120);
    return store.runTransaction(async tx => {
      const {family} = await familyContext(store, tx, uid);
      const ownerUid = family.childUid;
      const mirror = root(ownerUid);
      const state = (await tx.get(mirror)).data();
      if (!state) return {ownerUid, sourceId: null, sequence: 0, records: []};
      const entities = mirror.collection('entities');
      const records = new Map();
      const read = async (kind, id) => {
        const record = (await tx.get(entities.doc(`${kind}_${id}`))).data();
        if (record && !record.deleted) {
          const {digest, ingredientSearchPrefixes, ...visible} = record;
          records.set(`${kind}/${id}`, visible);
          return visible;
        }
        return null;
      };
      const query = async (kind, field, op, value, end) => {
        const base = entities.where('kind', '==', kind).where(field, op, value);
        const snapshot = await tx.get((end === undefined ? base : base.where(field, '<', end)).limit(201));
        if (snapshot.docs.length > 200) fail('resource-exhausted');
        return snapshot.docs.flatMap(doc => {
          const {digest, ingredientSearchPrefixes, ...record} = doc.data();
          return record.deleted ? [] : [record];
        });
      };
      const add = rows => {
        for (const row of rows) records.set(`${row.kind}/${row.id}`, row);
      };
      const distinct = ids => [...new Set(ids.filter(Number.isSafeInteger))];
      async function activities(start, end, includeCompletedSummary) {
        const [occurrences, ongoing, recent] = await Promise.all([
          query('activityOccurrences', 'payload.started_at', '>=', start, end),
          query('activityLogs', 'payload.ended_at', '==', null),
          query('activityLogs', 'payload.ended_at', '>=', start, end),
        ]);
        const upcoming = occurrences.filter(row => ['pending', 'planned'].includes(row.payload.status));
        const logs = includeCompletedSummary
          ? recent.filter(row => row.payload.summarized_at == null && row.payload.summary_dismissed_at == null)
          : recent;
        add([...upcoming, ...ongoing, ...logs]);
        await Promise.all([
          ...distinct([...upcoming, ...ongoing, ...logs].map(row => row.payload.activity_id))
            .map(id => read('activities', id)),
          ...distinct(upcoming.map(row => row.payload.activity_log_id)).map(id => read('activityLogs', id)),
          ...distinct(upcoming.map(row => row.payload.id)).map(id => read('activityOccurrenceReschedules', id)),
          ...(includeCompletedSummary
            ? distinct([...ongoing, ...logs].map(row => row.payload.id)).map(async id =>
                add(await query('activityOccurrences', 'payload.activity_log_id', '==', id)))
            : []),
        ]);
      }
      if (home) {
        const [timed, dateOnly, active] = await Promise.all([
          query('meals', 'payload.planned_at', '>=', data.startMs, data.endMs),
          query('meals', 'payload.planned_day', '==', data.date),
          query('meals', 'payload.status', 'in', [
            'eating', 'eating-extra', 'eating-then-bolus', 'waiting-for-bolus',
            'bolused-waiting', 'waited-eating', 'bolused-eating', 'eaten',
            'eaten-extra', 'eaten-bolused',
          ]),
          activities(data.startMs, data.endMs, true),
        ]);
        const plans = [...timed, ...dateOnly].filter(row => row.payload.status === 'planned');
        add([...plans, ...active].map(row => {
          const {id, name, planned_at, planned_day, status, purpose, add_on_progress, treatment_surplus} = row.payload;
          return {...row, payload: {id, name, planned_at, planned_day, status, purpose, ...(typeof add_on_progress === 'string' ? {add_on_progress} : {}), ...(treatment_surplus === 1 ? {treatment_surplus} : {})}};
        }));
        add(await query('workflowLocks', 'payload.active', '==', 1));
      } else {
        const meal = await read('meals', data.mealId);
        if (!meal) fail('not-found');
        const [items, snapshots, history] = await Promise.all([
          query('mealIngredients', 'payload.meal_id', '==', data.mealId),
          query('mealSnapshots', 'payload.meal_id', '==', data.mealId),
          query('mealHistory', 'payload.meal_id', '==', data.mealId),
        ]);
        add([...items, ...snapshots, ...history]);
        if (data.context) {
          const peers = await tx.get(entities.where('kind', '==', 'meals')
            .where('deleted', '==', false)
            .where('payload.name', '==', meal.payload.name)
            .where('payload.status', 'in', ['eaten', 'eaten-extra', 'eaten-bolused', 'summarized'])
            .orderBy('payload.created_at', 'desc')
            .limit(6));
          add(peers.docs.map(doc => {
            const {digest, ingredientSearchPrefixes, ...record} = doc.data();
            return record;
          }).filter(row => row.id !== meal.id).slice(0, 5));
        }
        await Promise.all([
          ...distinct(items.map(row => row.payload.ingredient_id)).map(async id => {
            if (!await read('ingredients', id)) fail('failed-precondition');
            const planned = snapshots.find(row => row.payload.snapshot_type === 'planned')?.payload;
            const consumed = snapshots.find(row => row.payload.snapshot_type === 'consumed')?.payload;
            const references = distinct([
              planned?.calculated_at ?? planned?.created_at ?? meal.payload.created_at,
              ...items.filter(row => row.payload.ingredient_id === id).map(row =>
                consumed?.calculated_at ?? consumed?.created_at ?? row.payload.created_at),
            ]);
            if (references.length === 0) {
              add(await query('ingredientHistory', 'payload.ingredient_id', '==', id));
              return;
            }
            await Promise.all(references.map(async reference => {
              // Each history row stores nutrition immediately before its edit.
              const firstLaterEdit = await tx.get(entities.where('kind', '==', 'ingredientHistory')
                .where('deleted', '==', false).where('payload.ingredient_id', '==', id)
                .where('payload.created_at', '>', reference).orderBy('payload.created_at').limit(1));
              for (const doc of firstLaterEdit.docs) {
                const {digest, ingredientSearchPrefixes, ...record} = doc.data();
                add([record]);
              }
            }));
          }),
          ...distinct(items.map(row => row.payload.portion_id)).map(id => read('portions', id)),
          ...(data.context ? [activities(Date.now() - 3 * hour, Date.now() + 2 * hour + 1, false)] : []),
        ]);
      }
      const result = {ownerUid, sourceId: state.sourceId, sequence: state.sequence, records: [...records.values()]};
      if (Buffer.byteLength(JSON.stringify(result)) > 2 * 1024 * 1024) fail('resource-exhausted');
      return result;
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
  return {register, publish, completeMealHeaderExport, fetch, fetchView, fetchMealHeaders, fetchMealProgress, searchIngredients};
}
module.exports = {createMirrorService, familyContext, validateRecord};
