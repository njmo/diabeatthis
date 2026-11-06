'use strict';
const test = require('node:test'); const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app'); const {getFirestore} = require('firebase-admin/firestore');
const {createFamilyService} = require('../../common/family_service.cjs'); const {createMirrorService} = require('../../common/mirror_service.cjs');
test('real mirror upload, delta download, tombstone and caregiver revocation are isolated', async () => {
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'mirror-roundtrip'); const store = getFirestore(app);
  const family = createFamilyService({store, auth: {getUser: async uid => ({emailVerified: true, providerData: [{providerId: 'google.com', displayName: uid}]})}});
  const mirror = createMirrorService({store}); const sourceId = 'c'.repeat(32);
  try {
    const invite = await family.createInvite('mirror-child', {});
    await family.requestJoin('mirror-parent', {inviteId: invite.id, token: invite.token}); await family.decide('mirror-child', {inviteId: invite.id, approve: true});
    await mirror.register('mirror-child', {sourceId});
    await mirror.publish('mirror-child', {sourceId, records: [{kind: 'portions', id: '1', revision: 1, deleted: false, payload: {id: 1, name: 'Spoon', unit_hint: 'unit'}}]});
    const page = await mirror.fetch('mirror-parent', {after: 0});
    assert.equal(page.ownerUid, 'mirror-child'); assert.equal(page.records[0].payload.name, 'Spoon'); assert.equal(page.records[0].digest, undefined);
    assert.deepEqual((await mirror.fetch('mirror-parent', {after: page.cursor})).records, []);
    await mirror.publish('mirror-child', {sourceId, records: [{kind: 'portions', id: '1', revision: 2, deleted: true, payload: null}]});
    assert.equal((await mirror.fetch('mirror-parent', {after: page.cursor})).records[0].deleted, true);
    await family.disconnect('mirror-parent', {memberId: 'self'});
    await assert.rejects(mirror.fetch('mirror-parent', {after: 0}));
    await assert.rejects(mirror.fetch('mirror-stranger', {after: 0}));
  } finally { await store.terminate(); await deleteApp(app); }
});
