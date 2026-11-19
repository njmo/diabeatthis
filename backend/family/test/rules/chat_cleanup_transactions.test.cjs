'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {createChatService, DAY} = require('../../common/chat_service.cjs');
const {createChatCleanup} = require('../../common/chat_cleanup.cjs');
const {createChatOrphanCleanup} = require('../../common/chat_orphan_cleanup.cjs');
const {createChatNotifications} = require('../../common/chat_notifications.cjs');
const {hash} = require('../../common/security.cjs');

test('real Firestore orphan cleanup preserves concurrent send metadata, sequence and refreshed device registration', async () => {
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'chat-orphan-transactions');
  const store = getFirestore(app);
  const fid = 'chat-orphan-family', child = 'orphan-child', mom = 'orphan-mom';
  const chat = createChatService({store, signingKey: () => 'emulator-only-secret'});
  const cleanup = () => createChatOrphanCleanup({store, chat, pageSize: 100});
  try {
    await store.doc(`families/${fid}`).set({childUid: child, memberUids: [child, mom], managerUids: [mom]});
    for (const [uid, role] of [[child, 'child'], [mom, 'managingCaregiver']]) {
      await store.doc(`familyAccounts/${uid}`).set({familyId: fid, role});
      await store.doc(`families/${fid}/members/${uid}`).set({role, joinedAt: 1, invitationId: uid, displayName: uid});
    }
    async function send(text) {
      const ticket = (await chat.reserve(mom, {count: 1})).tickets[0];
      return (await chat.send(mom, {ticket: ticket.token, targetUid: child, kind: 'text', text})).message;
    }
    const old = await send('Removed body');
    await store.doc(`families/${fid}/chatMessages/${old.id}`).delete();
    const [, next] = await Promise.all([cleanup().run(), send('Fresh body')]);
    assert.equal(next.sequence, 2);
    const conversation = (await store.doc(`families/${fid}/chatConversations/${next.conversationId}`).get()).data();
    assert.equal(conversation.sequence, 2); assert.equal(conversation.names[child], child);
    for (const [uid, epoch] of Object.entries(next.participants)) {
      assert.equal((await store.doc(`families/${fid}/chatInboxes/${hash(`${uid}:${epoch}`)}/threads/${next.conversationId}`).get()).exists, true);
      assert.equal((await store.doc(`families/${fid}/chatInboxes/${hash(`${uid}:${epoch}`)}/chatMessageIndex/${next.id}`).get()).exists, true);
    }
    const token = 'emulator-only-refreshed-child-token';
    const ref = store.doc(`familyChatDevices/${hash(token)}`);
    await ref.set({uid: child, familyId: fid, epoch: 'old', token});
    const notifications = createChatNotifications({store, chat, messaging: {}});
    await Promise.all([cleanup().run(), notifications.register(child, {enabled: true, token})]);
    assert.equal((await ref.get()).data().epoch, (await chat.getConfig(child, {})).epoch);
    await Promise.all([cleanup().run(), chat.configure(child, {accountEnabled: false, expectedRevision: 0})]);
    await cleanup().run();
    assert.equal((await ref.get()).exists, false);
  } finally { await store.terminate(); await deleteApp(app); }
});

test('real Firestore global cleanup resumes, reaches deleted parents, and serializes overlapping runners and policy changes', async () => {
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'chat-cleanup-transactions');
  const store = getFirestore(app);
  const fid = 'chat-cleanup-family', child = 'cleanup-child', mom = 'cleanup-mom';
  let time = Date.now();
  const chat = createChatService({store, now: () => time, signingKey: () => 'emulator-only-secret'});
  const cleanup = () => createChatCleanup({store, chat, now: () => time, pageSize: 2});
  try {
    await store.doc(`families/${fid}`).set({childUid: child, memberUids: [child, mom], managerUids: [mom]});
    for (const [uid, role] of [[child, 'child'], [mom, 'managingCaregiver']]) {
      await store.doc(`familyAccounts/${uid}`).set({familyId: fid, role});
      await store.doc(`families/${fid}/members/${uid}`).set({role, joinedAt: 1, invitationId: uid});
    }
    await chat.configure(mom, {retention: 'unlimited', expectedRevision: 0});
    const ticket = (await chat.reserve(mom, {count: 1})).tickets[0];
    const message = (await chat.send(mom, {ticket: ticket.token, targetUid: child, kind: 'text', text: 'PRIVATE BODY'})).message;
    const orphanId = 'orphan-message';
    await store.doc(`families/cleanup-deleted-parent/chatMessages/${orphanId}`).set({...message, id: orphanId});
    time += 2 * DAY;
    // Shortening may happen before or after the scan's first policy read. The
    // next complete cycle must delete it, never extend the original deadline.
    await Promise.all([cleanup().run(), cleanup().run(), chat.configure(mom, {retention: 'day', expectedRevision: 1})]);
    for (let count = 0; count < 30; count++) {
      await cleanup().run();
      if (!(await store.doc(`families/${fid}/chatMessages/${message.id}`).get()).exists &&
          !(await store.doc(`families/cleanup-deleted-parent/chatMessages/${orphanId}`).get()).exists) break;
    }
    assert.equal((await store.doc(`families/${fid}/chatMessages/${message.id}`).get()).exists, false);
    assert.equal((await store.doc(`families/cleanup-deleted-parent/chatMessages/${orphanId}`).get()).exists, false);
    for (const [uid, epoch] of Object.entries(message.participants)) {
      assert.equal((await store.doc(`families/${fid}/chatInboxes/${hash(`${uid}:${epoch}`)}/chatMessageIndex/${message.id}`).get()).exists, false);
    }
    assert.equal((await store.doc(`familyChatNotificationJobs/${hash(`${message.id}:${child}`)}`).get()).exists, false);
    assert.equal((await store.doc(`families/${fid}/chatOperationReceipts/${message.id}`).get()).exists, true);
    await assert.rejects(chat.send(mom, {ticket: ticket.token, targetUid: child, kind: 'text', text: 'PRIVATE BODY'}),
      error => ['failed-precondition', 'not-found'].includes(error.code));
  } finally { await store.terminate(); await deleteApp(app); }
});
