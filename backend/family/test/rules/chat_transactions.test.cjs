'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {getDoc, setDoc, doc} = require('firebase/firestore');
const {createChatService, DAY} = require('../../common/chat_service.cjs');
const {createFamilyService} = require('../../common/family_service.cjs');
const {createChatNotifications} = require('../../common/chat_notifications.cjs');
const {createChatTreatment, WINDOW} = require('../../common/chat_treatment.cjs');
const {hash} = require('../../common/security.cjs');

test('real Firestore personal clear serializes with a held send and duplicate clear preserves newer history', async () => {
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'chat-history-clear-race');
  const store = getFirestore(app);
  const fid = 'chat-clear-family', child = 'chat-clear-child', mom = 'chat-clear-mom';
  const chat = createChatService({store, signingKey: () => 'emulator-only-secret'});
  try {
    await store.doc(`families/${fid}`).set({childUid: child, memberUids: [child, mom], managerUids: [mom]});
    for (const [uid, role] of [[child, 'child'], [mom, 'managingCaregiver']]) {
      await store.doc(`familyAccounts/${uid}`).set({familyId: fid, role});
      await store.doc(`families/${fid}/members/${uid}`).set({role, joinedAt: 1, invitationId: uid});
    }
    const epoch = (await chat.getConfig(child, {})).epoch;
    const ticket = (await chat.reserve(mom, {count: 1})).tickets[0];
    let enter, release, held = false;
    const entered = new Promise(resolve => { enter = resolve; });
    const released = new Promise(resolve => { release = resolve; });
    const heldChat = createChatService({signingKey: () => 'emulator-only-secret', store: {
      doc: path => store.doc(path), collection: path => store.collection(path),
      runTransaction: action => store.runTransaction(tx => action({
        get: async ref => {
          const result = await tx.get(ref);
          if (ref.path === `familyChatAccounts/${child}` && !held) { held = true; enter(); await released; }
          return result;
        }, set: tx.set.bind(tx), delete: tx.delete.bind(tx), update: tx.update.bind(tx),
      })),
    }});
    const sending = heldChat.send(mom, {ticket: ticket.token, targetUid: child, kind: 'text', text: 'Before clear'});
    await entered;
    const clearing = chat.clearHistory(child, {expectedGeneration: 0, epoch, familyId: fid, operationId: 'clear-one'});
    release();
    const [sent] = await Promise.all([sending, clearing]);
    assert.equal((await chat.states(child, {ids: [sent.message.id]})).messages.length, 0);
    assert.equal((await chat.states(mom, {ids: [sent.message.id]})).messages.length, 1);
    const nextTicket = (await chat.reserve(mom, {count: 1})).tickets[0];
    const next = await chat.send(mom, {ticket: nextTicket.token, targetUid: child, kind: 'text', text: 'After clear'});
    await chat.clearHistory(child, {expectedGeneration: 0, epoch, familyId: fid, operationId: 'clear-one'});
    assert.equal((await chat.states(child, {ids: [next.message.id]})).messages.length, 1);
    assert.equal((await chat.states(child, {ids: [next.message.id]})).messages[0].historyGeneration, 1);
  } finally { await store.terminate(); await deleteApp(app); }
});

test('real Firestore verification racing a held original send past ticket expiry never declares it unsent or creates a second message', async () => {
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'chat-send-outcome-race');
  const store = getFirestore(app);
  const fid = 'chat-send-race-family', child = 'send-race-child', mom = 'send-race-mom';
  let time = Date.now();
  const chat = createChatService({store, now: () => time, signingKey: () => 'emulator-only-secret'});
  try {
    await store.doc(`families/${fid}`).set({childUid: child, memberUids: [child, mom], managerUids: [mom]});
    for (const [uid, role] of [[child, 'child'], [mom, 'managingCaregiver']]) {
      await store.doc(`familyAccounts/${uid}`).set({familyId: fid, role});
      await store.doc(`families/${fid}/members/${uid}`).set({role, joinedAt: 1, invitationId: uid});
    }
    const ticket = (await chat.reserve(mom, {count: 1})).tickets[0];
    const markerPath = `families/${fid}/chatOperationReceipts/${ticket.id}`;
    let enter, release;
    const entered = new Promise(resolve => { enter = resolve; });
    const released = new Promise(resolve => { release = resolve; });
    let held = false;
    const heldChat = createChatService({now: () => time, signingKey: () => 'emulator-only-secret', store: {
      doc: path => store.doc(path), collection: path => store.collection(path),
      runTransaction: action => store.runTransaction(tx => action({
        get: async ref => {
          const result = await tx.get(ref);
          if (ref.path === markerPath && !held) { held = true; enter(); await released; }
          return result;
        }, set: tx.set.bind(tx), delete: tx.delete.bind(tx), update: tx.update.bind(tx),
      })),
    }});
    const data = {ticket: ticket.token, targetUid: child, kind: 'text', text: 'Only one operation'};
    const original = heldChat.send(mom, data);
    await entered;
    time = ticket.expiresAt + 1;
    const verification = chat.send(mom, {...data, verifyOnly: true});
    // Register both rejection handlers before deliberately yielding: an honest
    // unknown outcome may arrive while the original transaction is still held.
    const settled = Promise.allSettled([original, verification]);
    // Let the competing transaction reach Firestore while the original is held.
    await new Promise(resolve => setTimeout(resolve, 50));
    release();
    const results = await settled;
    for (const result of results) {
      if (result.status === 'fulfilled') assert.equal(result.value.message.id, ticket.id);
      else assert.equal(result.reason.details?.reason, 'chat-send-outcome-unknown');
    }
    const rows = await store.collection(`families/${fid}/chatMessages`).get();
    assert.ok(rows.docs.length <= 1);
    if (rows.docs.length) assert.equal(rows.docs[0].id, ticket.id);
  } finally { await store.terminate(); await deleteApp(app); }
});

test('real Firestore compacts a legacy ledger under concurrent policy CAS without restoring expired messages', async () => {
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'chat-retention-compaction');
  const store = getFirestore(app);
  const fid = 'chat-compaction-family', child = 'chat-compaction-child', mom = 'chat-compaction-mom';
  let time = Date.now();
  const service = createChatService({store, now: () => time, signingKey: () => 'emulator-only-secret'});
  try {
    await store.doc(`families/${fid}`).set({childUid: child, memberUids: [child, mom], managerUids: [mom]});
    for (const [uid, role] of [[child, 'child'], [mom, 'managingCaregiver']]) {
      await store.doc(`familyAccounts/${uid}`).set({familyId: fid, role});
      await store.doc(`families/${fid}/members/${uid}`).set({role, joinedAt: 1, invitationId: uid});
    }
    await service.configure(mom, {retention: 'unlimited', expectedRevision: 0});
    const ticket = (await service.reserve(mom, {count: 1})).tickets[0];
    const sent = await service.send(mom, {ticket: ticket.token, targetUid: child, kind: 'text', text: 'Expired body'});
    const shortenings = Array.from({length: 128}, (_, index) => ({revision: index + 2, days: [1, 7, 30][index % 3], at: time}));
    await store.doc(`families/${fid}/chatConfig/current`).set({enabled: true, retention: 'unlimited', revision: 129, offGeneration: 0, shortenings});
    const results = await Promise.allSettled([
      service.configure(mom, {retention: 'week', expectedRevision: 129}),
      service.configure(mom, {retention: 'month', expectedRevision: 129}),
    ]);
    assert.equal(results.filter(value => value.status === 'fulfilled').length, 1);
    assert.equal(results.find(value => value.status === 'rejected').reason.code, 'already-exists');
    const config = await service.getConfig(child, {});
    assert.equal(config.policy.revision, 130);
    assert.ok(config.policy.shortenings.length <= 3);
    time += 2 * DAY;
    assert.equal((await service.states(child, {ids: [sent.message.id]})).messages.length, 0);
    assert.equal((await service.fetch(child, {targetUid: mom, latest: true})).messages.length, 0);
  } finally { await store.terminate(); await deleteApp(app); }
});

test('real Firestore founder initialization races the first caregiver join without overwriting policy', async () => {
  process.env.PAIRING_HMAC_KEY = 'chat-founder-emulator-only';
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'chat-founder-init');
  const store = getFirestore(app);
  const family = createFamilyService({store, auth: {getUser: async uid => ({emailVerified: true, providerData: [{providerId: 'google.com', displayName: uid, email: `${uid}@example.test`}]})}});
  const chat = createChatService({store, signingKey: () => 'emulator-only-secret'});
  try {
    const child = 'chat-founder-child', parent = 'chat-founder-parent';
    const invite = await family.createInvite(child, {});
    await family.requestJoin(parent, {inviteId: invite.id, token: invite.token});
    const [initialization, join] = await Promise.allSettled([
      chat.configure(child, {initializeIfAbsent: true, retention: 'day', expectedRevision: 0}),
      family.decide(child, {inviteId: invite.id, approve: true}),
    ]);
    assert.equal(join.status, 'fulfilled');
    let config = await chat.getConfig(parent, {});
    if (initialization.status === 'fulfilled') {
      assert.equal(initialization.value.initialized, true);
      assert.equal(config.policy.retention, 'day');
      assert.equal(config.policy.enabled, true);
      assert.equal(config.policy.offGeneration, 0);
    } else {
      assert.equal(initialization.reason.code, 'permission-denied');
      assert.equal(config.policyConfigured, false);
      assert.equal(config.policy.retention, 'week');
    }
    await chat.configure(parent, {retention: 'month', expectedRevision: config.policy.revision});
    assert.deepEqual(await chat.configure(child, {initializeIfAbsent: true, retention: 'day', expectedRevision: 0}), {ok: true, initialized: false});
    config = await chat.getConfig(parent, {});
    assert.equal(config.policy.retention, 'month');
  } finally { await store.terminate(); await deleteApp(app); }
});

test('real Firestore chat transactions deduplicate and deny direct client access', async () => {
  const app = initializeApp({projectId: 'demo-diabeatthis-family'}, 'chat-transactions');
  const store = getFirestore(app);
  const fid = 'chat-transaction-family', child = 'chat-child', mom = 'chat-mom';
  const service = createChatService({store, signingKey: () => 'emulator-only-secret'});
  const env = await initializeTestEnvironment({projectId: 'demo-diabeatthis-family', firestore: {rules: fs.readFileSync('firestore.rules', 'utf8')}});
  try {
    await store.doc(`families/${fid}`).set({childUid: child, memberUids: [child, mom], managerUids: [mom]});
    for (const [uid, role] of [[child, 'child'], [mom, 'managingCaregiver']]) {
      await store.doc(`familyAccounts/${uid}`).set({familyId: fid, role});
      await store.doc(`families/${fid}/members/${uid}`).set({role, joinedAt: 1, invitationId: uid});
    }
    const {tickets} = await service.reserve(mom, {count: 1});
    const data = {ticket: tickets[0].token, targetUid: child, kind: 'question', text: 'Przerwa?', answers: ['Tak']};
    const results = await Promise.all([service.send(mom, data), service.send(mom, data)]);
    assert.equal(results[0].message.id, results[1].message.id);
    const fetched = await service.fetch(child, {targetUid: mom, after: 0});
    assert.equal(fetched.messages.length, 1);
    await service.acknowledge(child, {messageId: fetched.messages[0].id, read: true});
    await service.acknowledgeBatch(child, {items: [{messageId: fetched.messages[0].id, read: true}, {messageId: 'unknown', read: false}]});
    assert.ok((await service.states(mom, {ids: [fetched.messages[0].id]})).messages[0].receipts[child].readAt);
    assert.equal((await service.fetch(child, {targetUid: mom, latest: true})).messages.length, 1);
    await service.saveShortcuts(mom, {items: [{id: 'meal', label: 'Posiłek', text: 'Masz śniadanie?', emoji: '🥪', answers: ['Mam']}], expectedRevision: 0});
    await service.orderShortcuts(mom, {ids: ['meal'], expectedRevision: 0});
    assert.equal((await service.shortcuts(mom, {})).items[0].id, 'meal');
    const pushes = [];
    const notifications = createChatNotifications({store, chat: service, messaging: {sendEachForMulticast: async message => { pushes.push(message); return {responses: [{success: true}]}; }}});
    await notifications.register(child, {enabled: true, token: 'emulator-only-child-token'});
    const jobId = hash(`${fetched.messages[0].id}:${child}`);
    await Promise.allSettled([notifications.dispatch(jobId), notifications.dispatch(jobId)]);
    assert.equal(pushes.length, 1);
    assert.equal(pushes[0].data.messageId, fetched.messages[0].id);
    assert.ok((await service.fetch(mom, {targetUid: child, after: 0})).messages[0].receipts[child].readAt);
    const treatment = createChatTreatment({store, chat: service});
    const treatmentTicket = (await service.reserve(mom, {count: 1})).tickets[0];
    const instruction = (await service.send(mom, {ticket: treatmentTicket.token, targetUid: child,
      kind: 'lowTreatment', text: 'Untrusted description', treatment: {foodName: 'Apple', quantity: 1,
        unit: 'piece', gramsPerUnit: 100, carbsPer100g: 12, validUntil: Date.now() + WINDOW - 1000}})).message;
    const claimConfig = await service.getConfig(child, {});
    const claimData = {messageId: instruction.id, installationId: 'phone-one', proof: 'a'.repeat(43),
      authorization: {epoch: claimConfig.epoch, accountOffGeneration: claimConfig.account.offGeneration, familyOffGeneration: claimConfig.policy.offGeneration}};
    const claims = await Promise.allSettled([
      treatment.claim(child, claimData),
      treatment.claim(child, {...claimData, installationId: 'phone-two', proof: 'b'.repeat(43)}),
    ]);
    assert.equal(claims.filter(value => value.status === 'fulfilled').length, 1);
    const winner = claims.find(value => value.status === 'fulfilled').value;
    const proof = claims[0].status === 'fulfilled' ? claimData.proof : 'b'.repeat(43);
    await treatment.complete(child, {claimId: winner.claimId, proof});
    for (const uid of [null, child, mom, 'chat-stranger']) {
      const db = uid ? env.authenticatedContext(uid, {email_verified: true, firebase: {sign_in_provider: 'google.com'}}).firestore() : env.unauthenticatedContext().firestore();
      for (const path of [`families/${fid}/chatMessages/${fetched.messages[0].id}`, `families/${fid}/chatShortcuts/questions`, `families/${fid}/chatShortcutOrders/private`, `familyChatDevices/${hash('emulator-only-child-token')}`, `familyChatAccounts/${child}`, `familyChatNotificationJobs/job`, `familyChatTreatmentClaims/${winner.claimId}`]) {
        await assertFails(getDoc(doc(db, path)));
        await assertFails(setDoc(doc(db, path), {text: 'forged'}));
      }
    }
  } finally {
    await env.cleanup();
    await deleteApp(app);
  }
});
