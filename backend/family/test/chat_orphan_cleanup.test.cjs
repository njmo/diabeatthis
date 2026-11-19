'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {MemoryStore} = require('./memory_store.cjs');
const {createChatService, DAY} = require('../common/chat_service.cjs');
const {createChatOrphanCleanup} = require('../common/chat_orphan_cleanup.cjs');
const {hash} = require('../common/security.cjs');

function fixture(pageSize = 100) {
  const store = new MemoryStore(); let time = 1000;
  store.values.set('families/one', {childUid: 'child', memberUids: ['child', 'mom'], managerUids: ['mom']});
  for (const [uid, role] of [['child', 'child'], ['mom', 'managingCaregiver']]) {
    store.values.set(`familyAccounts/${uid}`, {familyId: 'one', role});
    store.values.set(`families/one/members/${uid}`, {role, invitationId: uid, joinedAt: 1, displayName: `PRIVATE-${uid}`});
  }
  const chat = createChatService({store, now: () => time, signingKey: () => 'test-secret'});
  const cleanup = () => createChatOrphanCleanup({store, chat, now: () => time, pageSize});
  const send = async () => {
    const {tickets} = await chat.reserve('mom', {count: 1});
    return (await chat.send('mom', {ticket: tickets[0].token, targetUid: 'child', kind: 'text', text: 'PRIVATE BODY'})).message;
  };
  return {store, chat, cleanup, send, advance: value => { time += value; }};
}

test('missing bodies remove orphan indices and empty thread names while retaining conversation sequence', async () => {
  const {store, cleanup, send} = fixture();
  const message = await send();
  store.values.delete(`families/one/chatMessages/${message.id}`);
  const result = await cleanup().run();
  assert.equal(result.indices.deleted, 2); assert.equal(result.threads.deleted, 2);
  assert.equal(result.conversations.redacted, 1);
  assert.deepEqual(store.values.get(`families/one/chatConversations/${message.conversationId}`), {sequence: 1});
  const next = await send();
  assert.equal(next.sequence, 2);
  assert.equal(next.names.child, 'PRIVATE-child');
});

test('active indices and nonempty thread names survive, including when own chat account is OFF', async () => {
  const {store, cleanup, send} = fixture();
  await send();
  store.values.set('familyChatAccounts/child', {enabled: false, revision: 1, offGeneration: 1});
  const result = await cleanup().run();
  assert.equal(result.indices.deleted, 0); assert.equal(result.threads.deleted, 0); assert.equal(result.conversations.redacted, 0);
});

test('old membership epoch loses its private indices and names without deleting the other participant history', async () => {
  const {store, cleanup, send} = fixture();
  const message = await send();
  store.values.get('families/one/members/mom').joinedAt = 2;
  const result = await cleanup().run();
  assert.equal(result.indices.deleted, 1); assert.equal(result.threads.deleted, 1);
  assert.equal(store.values.has(`families/one/chatMessages/${message.id}`), true);
  const childIndex = `families/one/chatInboxes/${hash(`child:${message.participants.child}`)}/chatMessageIndex/${message.id}`;
  assert.equal(store.values.has(childIndex), true);
});

test('expired bodies may await body cleanup but their private indices no longer keep empty threads', async () => {
  const {store, cleanup, send, advance} = fixture();
  const message = await send(); advance(8 * DAY);
  const result = await cleanup().run();
  assert.equal(result.indices.deleted, 2); assert.equal(result.threads.deleted, 2);
  assert.equal(store.values.has(`families/one/chatMessages/${message.id}`), true);
  assert.equal(result.conversations.redacted, 0); // Body scan owns physical content deletion.
});

test('device registrations are revoked on account OFF or stale epoch but installation counter remains', async () => {
  const {store, chat, cleanup} = fixture();
  for (const uid of ['child', 'mom']) {
    const config = await chat.getConfig(uid, {});
    store.values.set(`familyChatDevices/${uid}`, {uid, familyId: 'one', epoch: config.epoch, token: 'PRIVATE_TOKEN'});
  }
  store.values.set('familyChatInstallations/minimal', {counter: 99, uid: 'child'});
  store.values.set('familyChatAccounts/child', {enabled: false, revision: 1, offGeneration: 1});
  store.values.get('familyChatDevices/mom').epoch = 'old';
  assert.equal((await cleanup().run()).devices.deleted, 2);
  assert.equal(store.values.get('familyChatInstallations/minimal').counter, 99);
});

test('active device registration survives cleanup', async () => {
  const {store, chat, cleanup} = fixture();
  const config = await chat.getConfig('child', {});
  store.values.set('familyChatDevices/active', {uid: 'child', familyId: 'one', epoch: config.epoch});
  assert.equal((await cleanup().run()).devices.deleted, 0);
  assert.equal(store.values.has('familyChatDevices/active'), true);
});

test('bounded passes resume after restart, do not delete unrelated threads, and tolerate overlapping runners', async () => {
  const {store, cleanup, send} = fixture(1);
  const message = await send();
  store.values.delete(`families/one/chatMessages/${message.id}`);
  store.values.set('other/doc/threads/not-chat', {displayName: 'NOT OUR DATA'});
  await Promise.all([cleanup().run(), cleanup().run()]);
  for (let count = 0; count < 6; count++) await cleanup().run();
  assert.equal([...store.values.keys()].filter(path => path.includes('/chatMessageIndex/')).length, 0);
  assert.equal([...store.values.keys()].filter(path => path.startsWith('families/') && path.includes('/threads/')).length, 0);
  assert.equal(store.values.has('other/doc/threads/not-chat'), true);
});

test('corrupt policy cannot cause valid private history to be erased by orphan cleanup', async () => {
  const {store, cleanup, send} = fixture();
  await send();
  store.values.set('families/one/chatConfig/current', {shortenings: [{revision: 1, days: 0}]});
  const result = await cleanup().run();
  assert.equal(result.indices.invalid, 2); assert.equal(result.indices.deleted, 0);
});
