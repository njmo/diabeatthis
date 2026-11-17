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
