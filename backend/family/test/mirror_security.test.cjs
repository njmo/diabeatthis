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
