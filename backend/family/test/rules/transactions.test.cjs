'use strict';
const test = require('node:test'); const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {createFamilyService} = require('../../common/family_service.cjs');
test('real Firestore transactions isolate families and serialize competing claims', async () => {
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'family-transactions');
  const store = getFirestore(app);
  const service = createFamilyService({store, auth: {getUser: async uid => ({emailVerified: true, providerData: [{providerId: 'google.com', displayName: uid, email: `${uid}@example.test`}]})}});
  try {
    const invite = await service.createInvite('tx-child', {});
    const attempts = await Promise.allSettled(['tx-parent', 'tx-attacker'].map(uid => service.requestJoin(uid, {inviteId: invite.id, token: invite.token})));
    assert.equal(attempts.filter(r => r.status === 'fulfilled').length, 1);
    const winner = attempts[0].status === 'fulfilled' ? 'tx-parent' : 'tx-attacker';
    assert.deepEqual((await service.status(winner, {})).members, []);
    await service.decide('tx-child', {inviteId: invite.id, approve: true});
    assert.equal((await service.status(winner, {})).members[0].id, 'tx-child');
    await service.finalize('tx-child', {});
    await assert.rejects(service.disconnect('tx-child', {memberId: winner}));
    await assert.rejects(service.status('tx-stranger', {familyId: 'tx-child'}));
  } finally { await store.terminate(); await deleteApp(app); }
});
