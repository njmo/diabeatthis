'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {MemoryStore} = require('./memory_store.cjs');
const {createChatService, DAY} = require('../common/chat_service.cjs');
const {createChatCleanup} = require('../common/chat_cleanup.cjs');
const {createChatTreatment} = require('../common/chat_treatment.cjs');
const {hash} = require('../common/security.cjs');

function fixture(pageSize = 100) {
  const store = new MemoryStore();
  let time = 1000;
  const chat = createChatService({store, now: () => time});
  const cleanup = () => createChatCleanup({store, chat, now: () => time, pageSize});
  const put = (fid, id, extra = {}) => {
    store.values.set(`families/${fid}`, {childUid: 'child'});
    const message = {id, sentAt: 1000, policyRevision: 0, expiresAt: 1000 + DAY,
      participants: {child: 'child-epoch', mom: 'mom-epoch'}, text: 'PRIVATE', ...extra};
    store.values.set(`families/${fid}/chatMessages/${id}`, message);
    for (const [uid, epoch] of Object.entries(message.participants)) {
      store.values.set(`families/${fid}/chatInboxes/${hash(`${uid}:${epoch}`)}/chatMessageIndex/${id}`, {conversationId: 'family'});
    }
    store.values.set(`familyChatNotificationJobs/${hash(`${id}:child`)}`, {familyId: fid, messageId: id, recipientUid: 'child'});
    store.values.set(`families/${fid}/chatOperationReceipts/${id}`, {uid: 'mom', digest: 'minimal'});
    store.values.set(`familyChatTreatmentClaims/${fid}-${id}`, {uid: 'child', messageId: id, proofDigest: 'minimal'});
  };
  return {store, cleanup, put, advance: value => { time += value; }};
}

test('expiry boundary deletes body, every participant index and scoped job but retains replay and clinical receipts', async () => {
  const {store, cleanup, put, advance} = fixture();
  put('one', 'expired'); put('two', 'future', {expiresAt: 1001 + DAY}); put('three', 'unlimited', {expiresAt: null});
  advance(DAY);
  const result = await cleanup().run();
  assert.equal(result.deleted, 1);
  assert.equal(result.skipped, 2);
  assert.equal(result.completed, true);
  assert.equal(store.values.has('families/one/chatMessages/expired'), false);
  assert.equal(store.values.has(`familyChatNotificationJobs/${hash('expired:child')}`), false);
  for (const [uid, epoch] of [['child', 'child-epoch'], ['mom', 'mom-epoch']]) {
    assert.equal(store.values.has(`families/one/chatInboxes/${hash(`${uid}:${epoch}`)}/chatMessageIndex/expired`), false);
  }
  assert.equal(store.values.has('families/one/chatOperationReceipts/expired'), true);
  assert.equal(store.values.has('familyChatTreatmentClaims/one-expired'), true);
});

test('bounded cursor survives restart, wraps, and revisits newly shortened unlimited messages', async () => {
  const {store, cleanup, put, advance} = fixture(1);
  put('one', 'a', {expiresAt: null}); put('one', 'b', {expiresAt: null});
  assert.equal((await cleanup().run()).scanned, 1);
  assert.equal((await cleanup().run()).scanned, 1);
  assert.equal((await cleanup().run()).completed, true);
  store.values.set('families/one/chatConfig/current', {shortenings: [{revision: 1, days: 1}]});
  advance(2 * DAY);
  assert.equal((await cleanup().run()).deleted, 1);
  assert.equal((await cleanup().run()).deleted, 1);
  assert.equal((await cleanup().run()).completed, true);
});

test('global collection group reaches orphan documents under a deleted parent family', async () => {
  const {store, cleanup, put} = fixture();
  put('gone', 'orphan', {expiresAt: null});
  store.values.delete('families/gone');
  assert.equal((await cleanup().run()).deleted, 1);
  assert.equal(store.values.has('families/gone/chatMessages/orphan'), false);
});

test('overlapping runners advance the same checkpoint atomically without skipping later documents', async () => {
  const {store, cleanup, put, advance} = fixture(1);
  put('one', 'a'); put('one', 'b'); advance(DAY);
  await Promise.all([cleanup().run(), cleanup().run()]);
  for (let count = 0; count < 4; count++) await cleanup().run();
  assert.equal([...store.values.keys()].filter(key => key.includes('/chatMessages/')).length, 0);
});

test('malformed record is retried on the next cycle without starving valid records', async () => {
  const {store, cleanup, put, advance} = fixture();
  put('one', 'a', {sentAt: 'invalid'}); put('one', 'b'); advance(DAY);
  const result = await cleanup().run();
  assert.equal(result.invalid, 1); assert.equal(result.deleted, 1);
  assert.equal(store.values.has('families/one/chatMessages/a'), true);
  assert.equal(store.values.get('familyChatMaintenance/messages').lastError, 'invalid-metadata');
  store.values.get('families/one/chatMessages/a').sentAt = 1000;
  assert.equal((await cleanup().run()).deleted, 1);
});

test('cleanup never deletes a hashed notification job belonging to a different scope', async () => {
  const {store, cleanup, put, advance} = fixture();
  put('one', 'a'); advance(DAY);
  const path = `familyChatNotificationJobs/${hash('a:child')}`;
  store.values.set(path, {familyId: 'other', messageId: 'a', recipientUid: 'child'});
  assert.equal((await cleanup().run()).deleted, 1);
  assert.equal(store.values.get(path).familyId, 'other');
});

test('minimal clinical completion still succeeds after source cleanup and cannot recreate message content', async () => {
  const {store, cleanup, put, advance} = fixture();
  put('one', 'a'); advance(DAY);
  const proof = 'a'.repeat(43), claimId = 'clinical-claim';
  store.values.set(`familyChatTreatmentClaims/${claimId}`, {uid: 'child', familyId: 'one', messageId: 'a',
    childEpoch: 'child-epoch', proofDigest: hash(proof), completedAt: null});
  await cleanup().run();
  const chat = createChatService({store});
  const treatment = createChatTreatment({store, chat});
  assert.deepEqual(await treatment.complete('child', {claimId, proof}), {ok: true});
  assert.equal(store.values.has('families/one/chatMessages/a'), false);
  assert.ok(store.values.get(`familyChatTreatmentClaims/${claimId}`).completedAt);
});
