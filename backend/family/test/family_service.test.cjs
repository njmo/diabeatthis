'use strict';
const test = require('node:test'); const assert = require('node:assert/strict');
const {createFamilyService} = require('../common/family_service.cjs');
const {MemoryStore} = require('./memory_store.cjs');
function fixture() {
  const store = new MemoryStore(); let time = 1000000;
  const auth = {getUser: async uid => ({emailVerified: true, providerData: [{providerId: 'google.com', displayName: uid, email: `${uid}@example.test`, photoURL: 'https://example.test/avatar'}]})};
  return {store, service: createFamilyService({store, auth, now: () => time}), advance: ms => {time += ms;}};
}
async function pair(service, child, parent) {
  const invite = await service.createInvite(child, {});
  await service.requestJoin(parent, {inviteId: invite.id, token: invite.token});
  await service.decide(child, {inviteId: invite.id, approve: true}); return invite;
}
test('scanning only creates a pending request; first membership needs child approval', async () => {
  const {service, store} = fixture(); const invite = await service.createInvite('child', {});
  assert.notEqual(store.values.get(`pairingInvites/${invite.id}`).tokenHash, invite.token);
  await service.requestJoin('parent', {inviteId: invite.id, token: invite.token});
  assert.deepEqual((await service.status('parent', {})).members, []);
  assert.equal((await service.status('child', {})).pending.displayName, 'parent');
  await assert.rejects(service.decide('stranger', {inviteId: invite.id, approve: true}));
  await service.decide('child', {inviteId: invite.id, approve: true});
  assert.equal((await service.status('parent', {})).members[0].id, 'child');
  await assert.rejects(service.requestJoin('other', {inviteId: invite.id, token: invite.token}));
});
test('expired, forged, self and superseded invites cannot grant access', async () => {
  const {service, advance} = fixture(); const old = await service.createInvite('child', {}); const next = await service.createInvite('child', {});
  await assert.rejects(service.requestJoin('stranger', {inviteId: old.id, token: old.token}));
  await assert.rejects(service.requestJoin('stranger', {inviteId: next.id, token: 'x'.repeat(43)}));
  await assert.rejects(service.requestJoin('child', {inviteId: next.id, token: next.token}));
  advance(300001); await assert.rejects(service.requestJoin('stranger', {inviteId: next.id, token: next.token}));
});
test('concurrent claims reserve one identity; neither gets membership automatically', async () => {
  const {service} = fixture(); const invite = await service.createInvite('child', {});
  const results = await Promise.allSettled(['parent', 'attacker'].map(uid => service.requestJoin(uid, {inviteId: invite.id, token: invite.token})));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.deepEqual((await service.status('parent', {})).members, []); assert.deepEqual((await service.status('attacker', {})).members, []);
});
test('existing manager must approve additional accounts, including after child reinstall', async () => {
  const {service} = fixture(); await pair(service, 'child', 'parent');
  const invite = await service.createInvite('child', {}); await service.requestJoin('parent2', {inviteId: invite.id, token: invite.token});
  await assert.rejects(service.decide('child', {inviteId: invite.id, approve: true}));
  assert.equal((await service.status('child', {})).pending, null);
  await service.decide('parent', {inviteId: invite.id, approve: true});
  assert.equal((await service.status('parent2', {})).members.length, 2);
});
test('cross-family status selectors, membership writes, approvals and removals fail', async () => {
  const {service} = fixture(); await pair(service, 'childA', 'parentA'); await pair(service, 'childB', 'parentB');
  await assert.rejects(service.status('parentA', {familyId: 'other'}));
  await assert.rejects(service.disconnect('parentA', {memberId: 'parentB'}));
  const invite = await service.createInvite('childB', {}); await service.requestJoin('candidate', {inviteId: invite.id, token: invite.token});
  await assert.rejects(service.decide('parentA', {inviteId: invite.id, approve: true}));
  await assert.rejects(service.requestJoin('candidate', {inviteId: invite.id, token: invite.token, role: 'child'}));
});
test('child cannot remove caregivers or reopen setup, while caregiver can leave their own family', async () => {
  const {service, advance} = fixture(); await pair(service, 'child', 'parent'); await service.finalize('child', {});
  await assert.rejects(service.disconnect('child', {memberId: 'parent'}));
  await assert.rejects(service.createInvite('parent', {}));
  await service.disconnect('parent', {memberId: 'self'});
  assert.deepEqual((await service.status('parent', {})).members, []);
  assert.deepEqual((await service.status('child', {})).members, []);
  const second = fixture(); await pair(second.service, 'child', 'parent'); second.advance(900001);
  await assert.rejects(second.service.disconnect('child', {memberId: 'parent'}));
  advance(1);
});
test('revocation removes account access immediately; another manager remains', async () => {
  const {service} = fixture(); await pair(service, 'child', 'parent'); await service.finalize('child', {});
  const invite = await service.createInvite('child', {}); await service.requestJoin('parent2', {inviteId: invite.id, token: invite.token}); await service.decide('parent', {inviteId: invite.id, approve: true});
  await service.disconnect('parent', {memberId: 'parent2'});
  assert.deepEqual((await service.status('parent2', {})).members, []);
  await assert.rejects(service.decide('parent2', {inviteId: invite.id, approve: true}));
});
test('rate limiting counts concurrent invalid attempts', async () => {
  const {service} = fixture(); const outcomes = await Promise.allSettled(Array.from({length: 12}, () => service.requestJoin('attacker', {inviteId: 'x'.repeat(43), token: 'y'.repeat(43)})));
  assert.equal(outcomes.filter(r => r.reason?.code === 'resource-exhausted').length, 2);
});
test('two visible devices plus action refreshes fit the status budget', async () => {
  const {service} = fixture();
  const requests = Array.from({length: 50}, () => service.status('parent', {}));
  assert.equal((await Promise.all(requests)).length, 50);
});
test('forged initial-setup flags never grant child removal authority', async () => {
  const {service} = fixture();
  await assert.rejects(service.createInvite('child', {initialSetup: true}));
  await pair(service, 'child', 'parent');
  await assert.rejects(service.createInvite('child', {initialSetup: true}));
  await assert.rejects(service.disconnect('child', {memberId: 'parent'}));
  await service.finalize('child', {});
  await assert.rejects(service.disconnect('child', {memberId: 'parent'}));
});
test('candidate sees only their own rejection or expiry, never family details', async () => {
  const {service, advance} = fixture();
  const invite = await service.createInvite('child', {});
  await service.requestJoin('candidate', {inviteId: invite.id, token: invite.token});
  assert.equal((await service.status('candidate', {})).joinState, 'pending');
  assert.equal((await service.status('stranger', {})).joinState, null);
  await service.decide('child', {inviteId: invite.id, approve: false});
  assert.deepEqual(await service.status('candidate', {}), {members: [], pending: null, joinState: 'rejected'});
  assert.equal((await service.status('child', {})).invitationState, 'rejected');
  const next = await service.createInvite('child', {});
  await service.requestJoin('candidate', {inviteId: next.id, token: next.token});
  advance(300001);
  assert.equal((await service.status('candidate', {})).joinState, 'expired');
});
test('a new claim cancels the candidate previous pending request atomically', async () => {
  const {service} = fixture(); const first = await service.createInvite('childA', {}); const next = await service.createInvite('childB', {});
  await service.requestJoin('candidate', {inviteId: first.id, token: first.token});
  await service.requestJoin('candidate', {inviteId: next.id, token: next.token});
  await assert.rejects(service.decide('childA', {inviteId: first.id, approve: true}));
  await service.decide('childB', {inviteId: next.id, approve: true});
  assert.equal((await service.status('candidate', {})).members[0].id, 'childB');
});
test('replacement invites have monotonic versions and cancel a pending scan', async () => {
  const {service} = fixture(); const first = await service.createInvite('child', {});
  await service.requestJoin('parent', {inviteId: first.id, token: first.token});
  const next = await service.createInvite('child', {});
  assert.ok(next.revision > first.revision);
  const status = await service.status('child', {});
  assert.equal(status.activeInvitationId, next.id); assert.equal(status.activeInvitationRevision, next.revision);
  assert.equal((await service.status('parent', {})).joinState, 'cancelled');
});
