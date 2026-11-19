'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {createChatService, DAY} = require('../../common/chat_service.cjs');

test('real Firestore unread uses indexed retention classes and atomic read receipts', async () => {
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'chat-unread-contract');
  const store = getFirestore(app);
  const run = Date.now();
  const fid = `chat-unread-${run}`, child = `unread-child-${run}`, mom = `unread-mom-${run}`;
  let time = Date.now();
  const chat = createChatService({store, now: () => time, signingKey: () => 'emulator-only-secret'});
  const send = async text => {
    const {tickets: [ticket]} = await chat.reserve(mom, {count: 1});
    return (await chat.send(mom, {ticket: ticket.token, targetUid: child, kind: 'text', text})).message;
  };
  const unread = async () => (await chat.conversations(child, {})).conversations[0].hasUnread;
  try {
    // Unique membership per run isolates retained emulator data without clearing it.
    await store.doc(`families/${fid}`).set({childUid: child, memberUids: [child, mom], managerUids: [mom]});
    for (const [uid, role] of [[child, 'child'], [mom, 'managingCaregiver']]) {
      await store.doc(`familyAccounts/${uid}`).set({familyId: fid, role});
      await store.doc(`families/${fid}/members/${uid}`).set({role, joinedAt: time, invitationId: uid});
    }
    await chat.configure(mom, {retention: 'unlimited', expectedRevision: 0});
    const first = await send('Old unlimited');
    assert.equal(await unread(), true);
    // All three non-dominated shortening frontiers plus the current class.
    await chat.configure(mom, {retention: 'day', expectedRevision: 1});
    await chat.configure(mom, {retention: 'unlimited', expectedRevision: 2});
    const second = await send('After day shortening');
    await chat.configure(mom, {retention: 'week', expectedRevision: 3});
    await chat.configure(mom, {retention: 'unlimited', expectedRevision: 4});
    const third = await send('After week shortening');
    await chat.configure(mom, {retention: 'month', expectedRevision: 5});
    await chat.configure(mom, {retention: 'unlimited', expectedRevision: 6});
    const fourth = await send('Current unlimited');
    await chat.acknowledgeBatch(child, {items: [second, third, fourth].map(message => ({messageId: message.id, read: true}))});
    assert.equal(await unread(), true);
    time += DAY;
    assert.equal(await unread(), false); // exact shortening boundary, not original TTL
    const newest = await send('New unread');
    assert.equal(await unread(), true);
    await chat.acknowledge(child, {messageId: newest.id, read: true});
    assert.equal(await unread(), false);
    assert.ok((await chat.states(child, {ids: [newest.id]})).messages[0].receipts[child].readAt);
    assert.equal((await chat.states(child, {ids: [first.id]})).messages.length, 0);
  } finally {
    await store.terminate();
    await deleteApp(app);
  }
});
