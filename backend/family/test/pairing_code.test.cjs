'use strict';
process.env.PAIRING_HMAC_KEY = 'pairing-code-test-secret';
const test = require('node:test');
const assert = require('node:assert/strict');
const {randomCrockford8, normalizeCrockford, formatCrockford8, hash, codeDigest} = require('../common/security.cjs');
const {createFamilyService} = require('../common/family_service.cjs');
const {MemoryStore} = require('./memory_store.cjs');
function fixture() {
  const store = new MemoryStore(); let time = 1000000;
  const auth = {getUser: async uid => ({emailVerified: true, providerData: [{providerId: 'google.com', displayName: uid, email: `${uid}@example.test`}]})};
  return {store, service: createFamilyService({store, auth, now: () => time}), advance: ms => {time += ms;}};
}
const denied = {code: 'permission-denied'};
const indexKey = code => `pairingCodeIndex/${codeDigest(normalizeCrockford(code))}`;
test('Crockford normalization accepts separators, lowercase and I/L/O aliases', () => {
  assert.equal(normalizeCrockford(' abcd-efgh '), 'ABCDEFGH');
  assert.equal(normalizeCrockford(' iL o0-12ab '), '110012AB');
  assert.equal(formatCrockford8('abcdefgh'), 'ABCD-EFGH');
  for (const code of [null, 12345678, '', '1234567', '123456789', 'UUUUUUUU', '1234_5678']) {
    assert.throws(() => normalizeCrockford(code), {code: 'invalid-argument'});
  }
  for (let i = 0; i < 100; i++) assert.match(randomCrockford8(), /^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$/);
});
test('createInvite returns a formatted shortCode with a hashed expiring index', async () => {
  const {service, store} = fixture();
  const invite = await service.createInvite('child', {});
  assert.match(invite.shortCode, /^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{4}-[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{4}$/);
  assert.deepEqual(store.values.get(indexKey(invite.shortCode)), {inviteId: invite.id, expiresAt: invite.expiresAt});
  assert.equal(invite.revision, 1);
  assert.equal(store.values.get(`pairingInvites/${invite.id}`).tokenHash, hash(invite.token));
});
test('joining by code creates only a pending request and is idempotent', async () => {
  const {service, store} = fixture();
  const invite = await service.createInvite('child', {});
  assert.deepEqual(await service.requestJoinByCode('parent', {code: invite.shortCode.toLowerCase()}), {pending: true});
  const before = structuredClone([...store.values].filter(([key]) => !key.startsWith('familyRateLimits/')));
  assert.deepEqual(await service.requestJoinByCode('parent', {code: invite.shortCode}), {pending: true});
  assert.deepEqual([...store.values].filter(([key]) => !key.startsWith('familyRateLimits/')), before);
  assert.equal(store.values.get(`pairingInvites/${invite.id}`).candidate.displayName, 'parent');
  assert.deepEqual(store.values.get('familyJoinRequests/parent'), {inviteId: invite.id});
  assert.equal(store.values.has('familyAccounts/parent'), false);
  await assert.rejects(service.requestJoinByCode('other', {code: invite.shortCode}), denied);
});
test('unknown codes count toward the join rate limit; malformed input is rejected', async () => {
  const {service} = fixture();
  await assert.rejects(service.requestJoinByCode('parent', {code: 'bad'}), {code: 'invalid-argument'});
  await assert.rejects(service.requestJoinByCode('parent', {code: '12345678', extra: true}), {code: 'invalid-argument'});
  for (let i = 0; i < 10; i++) await assert.rejects(service.requestJoinByCode('parent', {code: '12345678'}), denied);
  await assert.rejects(service.requestJoinByCode('parent', {code: '12345678'}), {code: 'resource-exhausted'});
});
test('both index and invite expiry are enforced, including the exact boundary', async () => {
  for (const target of ['index', 'invite', 'both']) {
    const {service, store, advance} = fixture();
    const invite = await service.createInvite('child', {});
    if (target === 'both') advance(300000);
    else store.values.get(target === 'index' ? indexKey(invite.shortCode) : `pairingInvites/${invite.id}`).expiresAt = 1000000;
    await assert.rejects(service.requestJoinByCode('parent', {code: invite.shortCode}), denied);
  }
});
test('self, superseded, existing-family and full-family requests are rejected', async () => {
  const {service, store} = fixture();
  const first = await service.createInvite('child', {});
  await assert.rejects(service.requestJoinByCode('child', {code: first.shortCode}), {code: 'failed-precondition'});
  const next = await service.createInvite('child', {});
  await assert.rejects(service.requestJoinByCode('parent', {code: first.shortCode}), denied);
  await service.createInvite('otherChild', {});
  await assert.rejects(service.requestJoinByCode('otherChild', {code: next.shortCode}), {code: 'failed-precondition'});
  const fid = store.values.get('familyAccounts/child').familyId;
  store.values.get(`families/${fid}`).memberUids = ['child', 'a', 'b', 'c', 'd', 'e'];
  await assert.rejects(service.requestJoinByCode('parent', {code: next.shortCode}), denied);
});
test('a new code claim cancels the previous pending request', async () => {
  const {service, store} = fixture();
  const a = await service.createInvite('childA', {});
  const b = await service.createInvite('childB', {});
  await service.requestJoinByCode('parent', {code: a.shortCode});
  await service.requestJoinByCode('parent', {code: b.shortCode});
  assert.equal(store.values.get(`pairingInvites/${a.id}`).state, 'cancelled');
  assert.deepEqual(store.values.get('familyJoinRequests/parent'), {inviteId: b.id});
});
// Simulate occupied hashes at the storage boundary without replacing the CSPRNG.
function collide(store, count, expiresAt = 2000000) {
  const original = store.runTransaction.bind(store); let reads = 0;
  store.runTransaction = action => original(tx => {
    const get = tx.get;
    tx.get = async ref => {
      if (ref.path.startsWith('pairingCodeIndex/')) {
        reads++;
        if (reads <= count) return {data: () => ({inviteId: 'occupied', expiresAt})};
      }
      return get(ref);
    };
    return action(tx);
  });
  return () => reads;
}
test('active collisions retry up to three attempts and never partially create a family', async () => {
  for (const count of [1, 2, 3]) {
    const {service, store} = fixture(); const reads = collide(store, count);
    if (count === 3) {
      await assert.rejects(service.createInvite('child', {}), {code: 'resource-exhausted'});
      assert.equal(store.values.has('familyAccounts/child'), false);
      assert.equal([...store.values.keys()].some(key => key.startsWith('pairingInvites/')), false);
    } else {
      const invite = await service.createInvite('child', {});
      assert.equal(store.values.get(indexKey(invite.shortCode)).inviteId, invite.id);
    }
    assert.equal(reads(), Math.min(count + 1, 3));
  }
});
test('expired index entries can be reused after the grace period', async () => {
  const {service, store} = fixture(); const reads = collide(store, 1, 1000000 - 3600000);
  const invite = await service.createInvite('child', {});
  assert.equal(reads(), 1);
  assert.equal(store.values.get(indexKey(invite.shortCode)).inviteId, invite.id);
});

test('raw input length is bounded before normalization', () => {
  for (const code of ['1234567', ' '.repeat(25) + '12345678', '-'.repeat(10000) + '12345678']) {
    assert.throws(() => normalizeCrockford(code), {code: 'invalid-argument'});
  }
  assert.equal(normalizeCrockford(' '.repeat(24) + '12345678'), '12345678');
});
test('codeDigest uses the configured or explicit key and fails closed even in tests', () => {
  const {createHmac} = require('node:crypto');
  const originalKey = process.env.PAIRING_HMAC_KEY;
  const originalEnv = process.env.NODE_ENV;
  try {
    assert.equal(codeDigest('12345678'), createHmac('sha256', originalKey).update('pairing-code:12345678').digest('hex'));
    delete process.env.PAIRING_HMAC_KEY;
    process.env.NODE_ENV = 'production';
    assert.throws(() => codeDigest('12345678'), {code: 'internal'});
    process.env.NODE_ENV = 'test';
    assert.throws(() => codeDigest('12345678'), {code: 'internal'});
    assert.equal(codeDigest('12345678', 'explicit-test-key'), createHmac('sha256', 'explicit-test-key').update('pairing-code:12345678').digest('hex'));
    assert.throws(() => codeDigest('12345678', ''), {code: 'internal'});
  } finally {
    process.env.PAIRING_HMAC_KEY = originalKey;
    if (originalEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = originalEnv;
  }
});
test('existing family accounts cannot distinguish active and unknown codes', async () => {
  const {service, store} = fixture();
  const invite = await service.createInvite('child', {});
  await service.createInvite('otherChild', {});
  store.values.delete(indexKey('12345678'));
  for (const code of [invite.shortCode, '12345678']) {
    await assert.rejects(service.requestJoinByCode('otherChild', {code}), {code: 'failed-precondition'});
  }
});
test('expired index entries remain reserved during the one-hour grace period', async () => {
  for (const elapsed of [0, 1, 3599999]) {
    const {service, store} = fixture();
    const reads = collide(store, 1, 1000000 - elapsed);
    const invite = await service.createInvite('child', {});
    assert.equal(reads(), 2);
    assert.equal(store.values.get(indexKey(invite.shortCode)).inviteId, invite.id);
  }
});
test('global code rate limit counts attempts across identities and resets after a minute', async () => {
  const {service, advance} = fixture();
  for (let i = 0; i < 300; i++) {
    await assert.rejects(service.requestJoinByCode('candidate-' + i, {code: '12345678'}), denied);
  }
  await assert.rejects(service.requestJoinByCode('next', {code: '12345678'}), {code: 'resource-exhausted'});
  advance(60000);
  await assert.rejects(service.requestJoinByCode('next', {code: '12345678'}), denied);
});

test('per-user rejection does not drain the global code budget', async () => {
  const {service, store} = fixture();
  for (let i = 0; i < 10; i++) {
    await assert.rejects(service.requestJoinByCode('over-limit', {code: '12345678'}), denied);
  }
  for (let i = 0; i < 300; i++) {
    await assert.rejects(service.requestJoinByCode('over-limit', {code: '12345678'}), {code: 'resource-exhausted'});
  }
  const globalRef = `familyRateLimits/${hash('global:join_code_attempt')}`;
  assert.equal(store.values.get(globalRef).count, 10);
  await assert.rejects(service.requestJoinByCode('another-user', {code: '12345678'}), denied);
  assert.equal(store.values.get(globalRef).count, 11);
});
