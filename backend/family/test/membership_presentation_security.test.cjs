'use strict';
process.env.PAIRING_HMAC_KEY = 'pairing-code-test-secret';
const test = require('node:test'); const assert = require('node:assert/strict');
const {MemoryStore} = require('./memory_store.cjs');
const {createFamilyService} = require('../common/family_service.cjs');
function fixture() {
  const store = new MemoryStore();
  return {store, service: createFamilyService({store, auth: {getUser: async uid => ({emailVerified: true, providerData: [{providerId: 'google.com', displayName: uid, email: `${uid}@example.test`}]})}})};
}
async function pair(service, child, parent, approver = child) {
  const invite = await service.createInvite(child, {});
  await service.requestJoin(parent, {inviteId: invite.id, token: invite.token});
  await service.decide(approver, {inviteId: invite.id, approve: true});
}
for (const memberId of ['self', 'child']) test(`caregiver unlinks their own membership using ${memberId}, preserving the child`, async () => {
  const {store, service} = fixture(); await pair(service, 'child', 'parent');
  const status = await service.status('parent', {});
  assert.equal(status.members[0].role, 'child'); assert.equal(status.members[0].canDisconnect, true); assert.equal(status.canLeave, true);
  await assert.rejects(service.disconnect('child', {memberId: 'parent'}));
  const pending = await service.createInvite('child', {});
  await service.requestJoin('candidate', {inviteId: pending.id, token: pending.token});
  await service.disconnect('parent', {memberId});
  assert.deepEqual((await service.status('parent', {})).members, []);
  assert.deepEqual((await service.status('child', {})).members, []);
  assert.ok(store.values.get('familyAccounts/child'));
  assert.equal((await service.status('candidate', {})).joinState, 'cancelled');
  await assert.rejects(service.decide('parent', {inviteId: pending.id, approve: true}));
});
test('self-unlink preserves the second caregiver and cannot affect another family', async () => {
  const {service} = fixture(); await pair(service, 'child', 'parent'); await pair(service, 'child', 'parent2', 'parent');
  await pair(service, 'other-child', 'other-parent');
  await assert.rejects(service.disconnect('parent', {memberId: 'other-child'}));
  await assert.rejects(service.disconnect('parent', {memberId: 'other-parent'}));
  await service.disconnect('parent', {memberId: 'child'});
  assert.equal((await service.status('parent2', {})).members[0].id, 'child');
  assert.deepEqual((await service.status('parent', {})).members, []);
  assert.equal((await service.status('other-parent', {})).members[0].id, 'other-child');
});
