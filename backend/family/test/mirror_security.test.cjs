'use strict';
process.env.PAIRING_HMAC_KEY = 'pairing-code-test-secret';
const test = require('node:test'); const assert = require('node:assert/strict');
const {MemoryStore} = require('./memory_store.cjs');
const {createFamilyService} = require('../common/family_service.cjs');
const {createMirrorService} = require('../common/mirror_service.cjs');
const sourceId = 'a'.repeat(32);
async function fixture() {
  const store = new MemoryStore();
  const family = createFamilyService({store, auth: {getUser: async uid => ({emailVerified: true, providerData: [{providerId: 'google.com', displayName: uid}]})}});
  const invitation = await family.createInvite('child', {}); await family.requestJoin('parent', {inviteId: invitation.id, token: invitation.token}); await family.decide('child', {inviteId: invitation.id, approve: true});
  const mirror = createMirrorService({store}); await mirror.register('child', {sourceId}); return {store, family, mirror};
}
const portion = revision => ({kind: 'portions', id: '1', revision, deleted: false, payload: {id: 1, name: 'Spoon', unit_hint: 'unit'}});
const meal = (id, payload = {}, revision = 1) => ({
  kind: 'meals', id: String(id), revision, deleted: false,
  payload: {
    ...Object.fromEntries(require('../common/mirror_contract.json').meals.columns.map(key => [key, null])),
    id, name: 'Pasta', status: 'summarized', category: 'lunch', purpose: 'meal',
    created_at: 500, notes: 'Private notes', ...payload,
  },
});
const mealHeaderRequest = {query: '', category: null, cursor: null};

test('child can confirm an empty initial meal header export exactly once', async () => {
  const {mirror, store} = await fixture();
  assert.equal((await mirror.register('child', {sourceId})).mealHeadersExportComplete, false);
  const initial = await mirror.fetchMealHeaders('parent', mealHeaderRequest);
  assert.equal(initial.initialHeadersComplete, false);
  assert.deepEqual(initial.records, []);
  assert.equal(initial.nextCursor, null);
  await assert.rejects(mirror.completeMealHeaderExport('parent', {sourceId}), {code: 'permission-denied'});
  await assert.rejects(mirror.completeMealHeaderExport('child', {sourceId: 'b'.repeat(32)}), {code: 'failed-precondition'});
  const completed = await mirror.completeMealHeaderExport('child', {sourceId});
  assert.deepEqual(completed, {sourceId, sequence: 0, mealHeadersRevision: 1});
  assert.deepEqual(await mirror.completeMealHeaderExport('child', {sourceId}), completed);
  assert.equal((await mirror.register('child', {sourceId})).mealHeadersExportComplete, true);
  assert.equal(store.values.get('familyMirrorSignals/parent').mealHeadersRevision, 1);
  const ready = await mirror.fetchMealHeaders('parent', mealHeaderRequest);
  assert.equal(ready.initialHeadersComplete, true);
  assert.deepEqual(ready.records, []);
  assert.equal(ready.nextCursor, null);
});

test('meal headers are bounded, minimized and ordered by effective date and numeric ID', async () => {
  const {mirror} = await fixture();
  const rows = [meal(1, {planned_at: 1800000000000}), meal(2, {planned_day: '2025-01-01'}),
    ...Array.from({length: 21}, (_, index) => meal(index + 3)),
    meal(24, {created_at: 499, category: 'dinner'}), portion(1)];
  await mirror.publish('child', {sourceId, records: rows});
  const first = await mirror.fetchMealHeaders('parent', mealHeaderRequest);
  assert.equal(first.ownerUid, 'child');
  assert.equal(first.sourceId, sourceId);
  assert.equal(first.sequence, 25);
  assert.equal(first.mealHeadersRevision, 1);
  assert.equal(first.initialHeadersComplete, false);
  assert.equal(first.records.length, 10);
  assert.deepEqual(first.records.slice(0, 4).map(record => record.id), ['1', '2', '23', '22']);
  assert.deepEqual(Object.keys(first.records[0].payload), [
    'id', 'name', 'status', 'category', 'purpose', 'planned_at', 'planned_day', 'created_at',
  ]);
  const next = await mirror.fetchMealHeaders('parent', {...mealHeaderRequest, cursor: first.nextCursor});
  assert.deepEqual(next.records.map(record => record.id), ['15', '14', '13', '12', '11', '10', '9', '8', '7', '6']);
  const last = await mirror.fetchMealHeaders('parent', {...mealHeaderRequest, cursor: next.nextCursor});
  assert.deepEqual(last.records.map(record => record.id), ['5', '4', '3', '24']);
  assert.equal(last.nextCursor, null);
  const dinner = await mirror.fetchMealHeaders('parent', {...mealHeaderRequest, category: 'dinner', query: ' AS '});
  assert.deepEqual(dinner.records.map(record => record.id), ['24']);
  await assert.rejects(mirror.fetchMealHeaders('parent', {...mealHeaderRequest, category: 'dinner', cursor: first.nextCursor}), {code: 'failed-precondition'});
  await assert.rejects(mirror.fetchMealHeaders('parent', {...mealHeaderRequest, query: 'other', cursor: first.nextCursor}), {code: 'failed-precondition'});
  await assert.rejects(mirror.fetchMealHeaders('parent', {...mealHeaderRequest, cursor: 'invalid'}), {code: 'invalid-argument'});
  await assert.rejects(mirror.fetchMealHeaders('parent', {...mealHeaderRequest, ownerUid: 'other'}), {code: 'invalid-argument'});
  await assert.rejects(mirror.fetchMealHeaders('stranger', mealHeaderRequest), {code: 'permission-denied'});
});

test('first meal page reads 11 header documents regardless of dependent record count', async () => {
  const {mirror, store} = await fixture();
  await mirror.publish('child', {sourceId, records: Array.from({length: 20}, (_, i) => meal(i + 1))});
  await mirror.completeMealHeaderExport('child', {sourceId});
  const counts = {mealIngredients: 583, mealHistory: 1350, mealSnapshots: 620, mealOrigins: 320};
  for (const [kind, count] of Object.entries(counts)) {
    for (let id = 1; id <= count; id++) {
      store.values.set(`userMirrors/child/entities/${kind}_${id}`, {
        kind, id: String(id), payload: {meal_id: 1}, deleted: false,
      });
    }
  }
  const queries = [];
  const transaction = store.runTransaction.bind(store);
  store.runTransaction = action => transaction(tx => action({
    ...tx,
    get: async ref => {
      const result = await tx.get(ref);
      if (ref.query) queries.push([ref.path, result.docs.length]);
      return result;
    },
  }));
  const page = await mirror.fetchMealHeaders('parent', mealHeaderRequest);
  assert.equal(page.records.length, 10);
  assert.deepEqual(queries, [['userMirrors/child/mealHeaders', 11]]);
});

test('legacy meal header migration is resumable and preserves concurrent edits and deletions', async () => {
  const {mirror, store} = await fixture();
  const path = 'userMirrors/child';
  delete store.values.get(path).mealHeadersBackfillAfter;
  for (let id = 1; id <= 80; id++) {
    const payload = {created_at: id, ...(id === 1 ? {name: 'Find this one'} : {})};
    store.values.set(`${path}/entities/meals_${id}`, {...meal(id, payload), sequence: id});
  }
  store.values.set(`${path}/entities/mealIngredients_1`, {kind: 'mealIngredients', id: '1', payload: {notes: 'Private'}});
  const request = {...mealHeaderRequest, query: 'Find'};
  const first = await mirror.fetchMealHeaders('parent', request);
  assert.equal(first.initialHeadersComplete, false);
  assert.deepEqual(first.records, []);
  assert.equal([...store.values.keys()].filter(key => key.startsWith(`${path}/mealHeaders/`)).length, 64);
  await Promise.all([
    mirror.publish('child', {sourceId, records: [
      meal(1, {name: 'Find the edited meal', created_at: 1}, 2),
      {kind: 'meals', id: '80', revision: 2, deleted: true, payload: null},
    ]}),
    mirror.fetchMealHeaders('parent', {...request, cursor: first.nextCursor}),
  ]);
  await mirror.completeMealHeaderExport('child', {sourceId});
  assert.equal(store.values.has(`${path}/mealHeaders/80`), false);
  assert.equal([...store.values.keys()].filter(key => key.startsWith(`${path}/mealHeaders/`)).length, 79);
  const scan = await mirror.fetchMealHeaders('parent', {...request, cursor: first.nextCursor});
  assert.equal(scan.initialHeadersComplete, true);
  assert.deepEqual(scan.records, []);
  assert.ok(scan.nextCursor);
  const last = await mirror.fetchMealHeaders('parent', {...request, cursor: scan.nextCursor});
  assert.equal(last.records[0].payload.name, 'Find the edited meal');
  assert.equal(last.nextCursor, null);
});

test('meal header continuation survives private edits and expires when a visible header changes', async () => {
  const {mirror, store} = await fixture();
  await mirror.publish('child', {sourceId, records: Array.from({length: 12}, (_, index) => meal(index + 1))});
  const first = await mirror.fetchMealHeaders('parent', mealHeaderRequest);
  const continuation = {...mealHeaderRequest, cursor: first.nextCursor};
  await mirror.publish('child', {sourceId, records: [meal(1, {notes: 'Updated private notes'}, 2), portion(1)]});
  assert.equal(store.values.get('familyMirrorSignals/parent').mealHeadersRevision, first.mealHeadersRevision);
  assert.deepEqual((await mirror.fetchMealHeaders('parent', continuation)).records.map(record => record.id), ['2', '1']);
  await mirror.publish('child', {sourceId, records: [meal(1, {name: 'Updated name'}, 3)]});
  assert.equal(store.values.get('familyMirrorSignals/parent').mealHeadersRevision, first.mealHeadersRevision + 1);
  await assert.rejects(mirror.fetchMealHeaders('parent', continuation), {code: 'failed-precondition'});
});

test('home reads plan summaries and meal view resolves only its dependencies', async () => {
  const {mirror, store} = await fixture();
  const now = Date.now();
  const start = now - 60000;
  const end = now + 60000;
  const date = new Date(now).toISOString().slice(0, 10);
  function seed(kind, id, payload) {
    store.values.set(`userMirrors/child/entities/${kind}_${id}`, {
      kind, id: String(id), payload, revision: 1, deleted: false,
    });
  }
  seed('meals', 1, {id: 1, name: 'Soup', planned_at: now, status: 'planned'});
  seed('meals', 2, {id: 2, name: 'Tomorrow', planned_at: end, status: 'planned'});
  seed('meals', 3, {id: 3, name: 'Soup', planned_at: start - 1, status: 'eating'});
  seed('meals', 4, {id: 4, name: 'Soup', planned_at: null, planned_day: date, status: 'planned'});
  seed('meals', 5, {id: 5, name: 'Soup', created_at: 5, planned_at: start - 2, status: 'summarized'});
  seed('mealIngredients', 1, {meal_id: 1, ingredient_id: 1, portion_id: 1});
  seed('mealIngredients', 2, {meal_id: 2, ingredient_id: 2});
  seed('ingredients', 1, {id: 1, name: 'Carrot'});
  seed('ingredients', 2, {id: 2, name: 'Bean'});
  seed('portions', 1, {id: 1, name: 'Spoon'});
  seed('ingredientHistory', 1, {ingredient_id: 1});
  seed('mealSnapshots', 1, {meal_id: 1});
  const home = {view: 'home', date, startMs: start, endMs: end};
  const meal = {view: 'meal', mealId: 1, context: true};
  const ids = response => response.records.map(row => `${row.kind}/${row.id}`).sort();
  assert.deepEqual(ids(await mirror.fetchView('parent', home)), ['meals/1', 'meals/3', 'meals/4']);
  assert.deepEqual(ids(await mirror.fetchView('parent', meal)), [
    'ingredientHistory/1', 'ingredients/1', 'mealIngredients/1',
    'mealSnapshots/1', 'meals/1', 'meals/5', 'portions/1',
  ]);
  for (let id = 10; id < 230; id++) {
    seed('meals', id, {id, name: 'Soup', created_at: id, status: 'summarized'});
  }
  assert.deepEqual(ids(await mirror.fetchView('parent', meal)).filter(id => id.startsWith('meals/')), [
    'meals/1', 'meals/225', 'meals/226', 'meals/227', 'meals/228', 'meals/229',
  ]);
  await assert.rejects(mirror.fetchView('stranger', meal), {code: 'permission-denied'});
  await assert.rejects(mirror.fetchView('parent', {...meal, ownerUid: 'stranger'}), {code: 'invalid-argument'});
  store.values.delete('userMirrors/child/entities/ingredients_1');
  await assert.rejects(mirror.fetchView('parent', meal), {code: 'failed-precondition'});
});

test('watch progress reads only projected transitions for the requested meal', async () => {
  const {mirror, store} = await fixture();
  const entities = 'userMirrors/child/entities/';
  store.values.set(entities + 'mealHistory_1', {
    kind: 'mealHistory', id: '1', deleted: false,
    payload: {meal_id: 4, status: 'eating', created_at: 100, notes: 'omit'},
  });
  store.values.set(entities + 'mealHistory_2', {
    kind: 'mealHistory', id: '2', deleted: false,
    payload: {meal_id: 5, status: 'eating', created_at: 101},
  });
  store.values.set(entities + 'mealIngredients_1', {
    kind: 'mealIngredients', id: '1', deleted: false,
    payload: {meal_id: 4, ingredient_id: 3},
  });
  const result = await mirror.fetchMealProgress('parent', {mealId: 4});
  assert.deepEqual(result.records, [{
    kind: 'mealHistory', id: '1', deleted: false,
    payload: {meal_id: 4, status: 'eating', created_at: 100},
  }]);
  await assert.rejects(mirror.fetchMealProgress('stranger', {mealId: 4}), {code: 'permission-denied'});
});
test('only the child publishes; revisions prevent stale and conflicting overwrites', async () => {
  const {mirror, store} = await fixture();
  await assert.rejects(mirror.publish('parent', {sourceId, records: [portion(1)]}));
  await assert.rejects(mirror.register('stranger', {sourceId}));
  await mirror.publish('child', {sourceId, records: [portion(2)]});
  await mirror.publish('child', {sourceId, records: [portion(2)]});
  assert.equal(store.values.get('userMirrors/child').sequence, 1);
  await assert.rejects(mirror.publish('child', {sourceId, records: [portion(1)]}));
  await assert.rejects(mirror.publish('child', {sourceId, records: [{...portion(2), payload: {...portion(2).payload, name: 'Fork'}}]}));
  await assert.rejects(mirror.register('child', {sourceId: 'b'.repeat(32)}));
  assert.equal(store.values.get('familyMirrorSignals/parent').ownerUid, 'child');
  assert.equal(store.values.has('familyMirrorSignals/stranger'), false);
});
test('mirror API rejects foreign owner selectors, unsupported fields and forged entity identities', async () => {
  const {mirror} = await fixture();
  await assert.rejects(mirror.publish('child', {sourceId, ownerUid: 'other-child', records: [portion(1)]}));
  await assert.rejects(mirror.publish('child', {sourceId, records: [{...portion(1), payload: {...portion(1).payload, executeBolus: true}}]}));
  await assert.rejects(mirror.publish('child', {sourceId, records: [{...portion(1), id: '2'}]}));
  await assert.rejects(mirror.fetch('parent', {after: 0, ownerUid: 'other-child'}));
  await assert.rejects(mirror.fetch('stranger', {after: 0}));
});
test('deletions are explicit tombstones, not silent missing records', async () => {
  const {mirror, store} = await fixture();
  await mirror.publish('child', {sourceId, records: [portion(1)]});
  await mirror.publish('child', {sourceId, records: [{kind: 'portions', id: '1', revision: 2, deleted: true, payload: null}]});
  assert.equal(store.values.get('userMirrors/child/entities/portions_1').deleted, true);
});

test('extra bolus progress survives active home projection without exporting treatment data', async () => {
  const {mirror} = await fixture();
  const now = Date.now();
  const date = new Date(now).toISOString().slice(0, 10);
  const home = {view: 'home', date, startMs: now - 60000, endMs: now + 60000};
  const columns = require('../common/mirror_contract.json').meals.columns;
  const base = Object.fromEntries(columns.filter(key => key !== 'planned_day').map(key => [key, null]));
  const record = {kind: 'meals', id: '1', revision: 1, deleted: false,
    payload: {...base, id: 1, name: 'Soup', purpose: 'meal', status: 'eating-extra'}};
  await mirror.publish('child', {sourceId, records: [record]});
  const progress = {originalStatus: 'eating-then-bolus', awaitingBolus: 1, additionalServing: 1, bolusBeforeExtra: 1};
  await mirror.publish('child', {sourceId, records: [{...record, revision: 2,
    payload: {...record.payload, planned_day: date, add_on_progress: JSON.stringify(progress), treatment_surplus: 1}}]});
  const result = (await mirror.fetchView('parent', home)).records.find(row => row.kind === 'meals');
  assert.deepEqual(JSON.parse(result.payload.add_on_progress), progress);
  assert.equal(result.payload.treatment_surplus, 1);
  await assert.rejects(mirror.publish('child', {sourceId, records: [{...record, revision: 3,
    payload: {...record.payload, treatment_surplus: 5}}]}), {code: 'invalid-argument'});
  await assert.rejects(mirror.publish('child', {sourceId, records: [{...record, revision: 3,
    payload: {...record.payload, add_on_progress: JSON.stringify({...progress, requestedCarbs: 20})}}]}),
    {code: 'invalid-argument'});
});
