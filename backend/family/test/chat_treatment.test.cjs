'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {MemoryStore} = require('./memory_store.cjs');
const {createChatService} = require('../common/chat_service.cjs');
const {createChatTreatment, WINDOW} = require('../common/chat_treatment.cjs');
const {createChatNotifications} = require('../common/chat_notifications.cjs');
const {hash} = require('../common/security.cjs');
const authorization = {epoch: hash(JSON.stringify(['child', 1])), accountOffGeneration: 0, familyOffGeneration: 0};

function fixture() {
  const store = new MemoryStore();
  let time = 1000000;
  for (const uid of ['child', 'mom']) {
    const role = uid === 'child' ? 'child' : 'managingCaregiver';
    store.values.set(`familyAccounts/${uid}`, {familyId: 'one', role});
    store.values.set(`families/one/members/${uid}`, {role, joinedAt: 1, invitationId: uid});
  }
  store.values.set('families/one', {childUid: 'child', memberUids: ['child', 'mom'], managerUids: ['mom']});
  const chat = createChatService({store, now: () => time, signingKey: () => 'test'});
  const treatment = createChatTreatment({store, chat, now: () => time});
  const snapshot = () => ({foodName: 'Candy', unit: 'piece', quantity: 2, gramsPerUnit: 5, carbsPer100g: 80, validUntil: time + WINDOW});
  async function send(extra = {}, uid = 'mom') {
    const {tickets} = await chat.reserve(uid, {count: 1});
    return chat.send(uid, {ticket: tickets[0].token, targetUid: uid === 'mom' ? 'child' : 'mom', kind: 'lowTreatment', text: 'Please eat', treatment: snapshot(), ...extra});
  }
  return {store, chat, treatment, send, snapshot, now: () => time, advance: delta => { time += delta; }};
}
const rejected = error => ['invalid-argument', 'permission-denied', 'not-found', 'already-exists', 'failed-precondition'].includes(error.code);

for (const clearingUid of ['child', 'mom']) {
  test(`personal clear stops new child claims, while an already issued lease may complete: ${clearingUid}`, async () => {
    const {send, chat, treatment, store} = fixture();
    const {message} = await send();
    const request = {messageId: message.id, installationId: 'phone', proof: 'a'.repeat(43), authorization};
    const claim = await treatment.claim('child', request);
    const epoch = (await chat.getConfig(clearingUid, {})).epoch;
    await chat.clearHistory(clearingUid, {familyId: 'one', epoch, expectedGeneration: 0, operationId: 'clear-one'});
    if (clearingUid === 'child') {
      await assert.rejects(treatment.claim('child', request), e => e.details?.reason === 'consumption-request-unavailable');
    }
    assert.deepEqual(await treatment.complete('child', {claimId: claim.claimId, proof: request.proof}), {ok: true});
    const source = store.values.get(`families/one/chatMessages/${message.id}`);
    assert.equal(source.treatmentResult.uid, 'child');
    const results = [...store.values.values()].filter(value => value.kind === 'treatmentResult');
    assert.equal(results.length, clearingUid === 'child' ? 0 : 1);
    if (results.length) {
      const visible = await chat.states('mom', {ids: [results[0].id]});
      assert.equal(visible.messages[0].historyGeneration, 1);
      assert.equal(visible.messages[0].historyGenerations, undefined);
    }
  });
}

test('permanent consumption expiry is distinct from temporary sender OFF without probing inaccessible source types', async () => {
  const {send, treatment, store, chat, advance} = fixture();
  const {message} = await send();
  const data = {messageId: message.id, installationId: 'phone', proof: 'a'.repeat(43), authorization};
  await chat.configure('mom', {accountEnabled: false, expectedRevision: 0});
  await assert.rejects(treatment.claim('child', data), error => error.code === 'not-found' && error.details === undefined);
  await chat.configure('mom', {accountEnabled: true, expectedRevision: 1});
  assert.ok((await treatment.claim('child', data)).claimId);
  advance(WINDOW);
  await assert.rejects(treatment.claim('child', data), error => error.details?.reason === 'consumption-request-expired');
  const source = store.values.get(`families/one/chatMessages/${message.id}`);
  source.kind = 'text';
  await assert.rejects(treatment.claim('child', data), error => error.details?.reason === 'consumption-request-unavailable');
  store.values.delete(`families/one/chatMessages/${message.id}`);
  await assert.rejects(treatment.claim('child', data), error => error.details?.reason === 'consumption-request-unavailable');
});

test('consumption expiry reasons require current child consent and its own participant epoch first', async () => {
  const {send, treatment, store, chat, advance} = fixture();
  const {message} = await send();
  const data = {messageId: message.id, installationId: 'phone', proof: 'a'.repeat(43), authorization};
  advance(WINDOW);
  const source = store.values.get(`families/one/chatMessages/${message.id}`);
  source.participants.child = 'not-current';
  await assert.rejects(treatment.claim('child', data), error => error.details?.reason === 'consumption-request-unavailable');
  await chat.configure('child', {accountEnabled: false, expectedRevision: 0});
  await chat.configure('child', {accountEnabled: true, expectedRevision: 1});
  await assert.rejects(treatment.claim('child', data), error => error.code === 'failed-precondition' && error.details === undefined);
  await assert.rejects(treatment.claim('mom', {...data, authorization: {...authorization, epoch: hash(JSON.stringify(['mom', 1]))}}),
    error => error.code === 'permission-denied' && error.details === undefined);
});

for (const target of ['account', 'family']) {
  for (const alreadyClaimed of [false, true]) {
    test(`an immutable intent cannot cross ${target} OFF→ON: claimed=${alreadyClaimed}`, async () => {
      const {send, chat, treatment, store} = fixture();
      const {message} = await send();
      const data = {messageId: message.id, installationId: 'phone', proof: 'a'.repeat(43), authorization};
      const claim = alreadyClaimed ? await treatment.claim('child', data) : null;
      if (target === 'account') {
        await chat.configure('child', {accountEnabled: false, expectedRevision: 0});
        await chat.configure('child', {accountEnabled: true, expectedRevision: 1});
      } else {
        // A legacy family policy already re-enabled after an earlier OFF.
        store.values.set('families/one/chatConfig/current', {enabled: true, offGeneration: 1, revision: 2});
      }
      await assert.rejects(treatment.claim('child', data), error => error.code === 'failed-precondition');
      if (claim) {
        const changed = {...authorization, [target === 'account' ? 'accountOffGeneration' : 'familyOffGeneration']: 1};
        await assert.rejects(treatment.claim('child', {...data, authorization: changed}), error => error.code === 'failed-precondition');
        assert.deepEqual(await treatment.complete('child', {claimId: claim.claimId, proof: data.proof}), {ok: true});
      }
    });
  }
}

test('legacy unversioned claims cannot renew, but existing effects can still finalize minimally', async () => {
  const {send, treatment, store} = fixture();
  const {message} = await send();
  const data = {messageId: message.id, installationId: 'phone', proof: 'a'.repeat(43), authorization};
  await assert.rejects(treatment.claim('child', {...data, authorization: undefined}), rejected);
  const claim = await treatment.claim('child', data);
  const previous = store.values.get(`familyChatTreatmentClaims/${claim.claimId}`);
  delete previous.authorization;
  await assert.rejects(treatment.claim('child', data), error => error.code === 'failed-precondition');
  await treatment.complete('child', {claimId: claim.claimId, proof: data.proof});
});

test('actual consumption quantity is frozen per claim and reported without changing the source proposal', async () => {
  const {send, chat, treatment, store} = fixture();
  const {message} = await send();
  const request = {messageId: message.id, installationId: 'phone', proof: 'a'.repeat(43), quantity: 1, authorization};
  const claim = await treatment.claim('child', request);
  assert.equal(claim.treatment.quantity, 1);
  assert.equal(claim.treatment.grams, 5);
  assert.equal(claim.treatment.carbs, 4);
  assert.equal(claim.treatment.deliveryCarbs, 4);
  assert.equal(claim.treatment.carbsPerUnit, message.treatment.carbsPerUnit);
  assert.equal((await treatment.claim('child', request)).claimId, claim.claimId);
  await assert.rejects(treatment.claim('child', {...request, quantity: 2}), rejected);
  await assert.rejects(treatment.claim('child', {messageId: message.id, installationId: 'phone', proof: request.proof, authorization}), rejected);
  await treatment.complete('child', {claimId: claim.claimId, proof: request.proof});
  const rows = (await chat.fetch('mom', {targetUid: 'child', latest: true})).messages;
  assert.equal(rows[0].treatment.quantity, 2);
  assert.equal(rows[1].text, 'Zjadłem · 1 × Candy · 4 g WW');
  assert.equal(store.values.get(`families/one/chatMessages/${message.id}`).treatmentResult.quantity, 1);
  assert.deepEqual(await treatment.claim('child', request), {claimId: claim.claimId, completed: true});
});

test('actual reference portions retain no invented mass and invalid quantities never claim', async () => {
  const {send, treatment, store, snapshot} = fixture();
  const {message} = await send({treatment: {...snapshot(), unit: 'portion', gramsPerUnit: null, carbsPer100g: null, carbsPerUnit: 6.5}});
  const request = {messageId: message.id, installationId: 'phone', proof: 'a'.repeat(43), authorization};
  for (const quantity of [0, -1, null, '1', Infinity, .001, 10001]) {
    await assert.rejects(treatment.claim('child', {...request, quantity}), rejected);
  }
  assert.equal([...store.values.keys()].filter(path => path.startsWith('familyChatTreatmentClaims/')).length, 0);
  const claim = await treatment.claim('child', {...request, quantity: 1});
  assert.equal(claim.treatment.grams, null);
  assert.equal(claim.treatment.carbs, 6.5);
  assert.equal(claim.treatment.deliveryCarbs, 7);
});

test('successful confirmation atomically creates one ordinary child response with real caregiver receipts and push job', async () => {
  const {send, chat, treatment, store} = fixture();
  const {message} = await send();
  const proof = 'a'.repeat(43);
  const claim = await treatment.claim('child', {messageId: message.id, installationId: 'phone', proof, authorization});
  await Promise.all([treatment.complete('child', {claimId: claim.claimId, proof}), treatment.complete('child', {claimId: claim.claimId, proof})]);
  const rows = (await chat.fetch('mom', {targetUid: 'child', latest: true})).messages;
  assert.equal(rows.length, 2);
  const answer = rows[1];
  assert.equal(answer.kind, 'treatmentResult');
  assert.equal(answer.senderUid, 'child');
  assert.equal(answer.replyTo, message.id);
  assert.equal(answer.sequence, rows[0].sequence + 1);
  assert.equal(answer.text, 'Zjadłem · 2 × Candy · 8 g WW');
  assert.deepEqual(answer.receipts.mom, {deliveredAt: null, readAt: null});
  assert.equal(store.values.get(`familyChatNotificationJobs/${hash(`${answer.id}:mom`)}`).recipientUid, 'mom');
  await assert.rejects(send({kind: 'treatmentResult'}, 'child'), rejected);
});

test('group confirmation includes only original caregivers still enabled, never a later family member', async () => {
  const {send, chat, treatment, store} = fixture();
  const addParent = uid => {
    store.values.set(`familyAccounts/${uid}`, {familyId: 'one', role: 'managingCaregiver'});
    store.values.set(`families/one/members/${uid}`, {role: 'managingCaregiver', joinedAt: 1, invitationId: uid});
    const family = store.values.get('families/one');
    store.values.set('families/one', {...family, memberUids: [...family.memberUids, uid], managerUids: [...family.managerUids, uid]});
  };
  addParent('dad');
  const {message} = await send({targetUid: 'family'});
  const proof = 'a'.repeat(43);
  const claim = await treatment.claim('child', {messageId: message.id, installationId: 'phone', proof, authorization});
  addParent('later');
  store.values.set('familyChatAccounts/dad', {enabled: false, revision: 1});
  await treatment.complete('child', {claimId: claim.claimId, proof});
  const rows = (await chat.fetch('mom', {targetUid: 'family', latest: true})).messages;
  assert.deepEqual(Object.keys(rows[1].receipts), ['mom']);
  assert.deepEqual((await chat.states('later', {ids: rows.map(row => row.id)})).messages, []);
});

test('completion after instruction expiry is minimal and does not turn an old fact into a new chat message', async () => {
  const {send, treatment, store, advance} = fixture();
  const {message} = await send();
  const proof = 'a'.repeat(43);
  const claim = await treatment.claim('child', {messageId: message.id, installationId: 'phone', proof, authorization});
  advance(WINDOW);
  await treatment.complete('child', {claimId: claim.claimId, proof});
  assert.equal([...store.values.keys()].filter(path => path.startsWith('families/one/chatMessages/')).length, 1);
  assert.equal(store.values.get(`families/one/chatMessages/${message.id}`).treatmentResult.uid, 'child');
});

test('instruction push TTL cannot outlive medical validity and a delayed job sends nothing', async () => {
  const {send, chat, store, now, advance} = fixture();
  const pushes = [];
  const notifications = createChatNotifications({store, chat, now, messaging: {sendEachForMulticast: async value => {pushes.push(value); return {responses: [{success: true}]};}}});
  await notifications.register('child', {enabled: true, token: 'child-notification-token'});
  const first = (await send()).message;
  await notifications.dispatch(hash(`${first.id}:child`));
  assert.equal(pushes[0].android.ttl, WINDOW);
  const second = (await send()).message;
  advance(WINDOW);
  const delayed = hash(`${second.id}:child`);
  await notifications.dispatch(delayed);
  assert.equal(pushes.length, 1);
  assert.equal(store.values.get(`familyChatNotificationJobs/${delayed}`).status, 'cancelled');
});

for (const entry of require('../../../test/fixtures/family_treatment_rounding.json')) {
  test(`nutrition and whole-gram delivery share the Dart boundary contract: ${entry.input}`, async () => {
    const {send} = fixture();
    const promise = send({treatment: {foodName: 'Reference', quantity: 1, unit: 'portion',
      carbsPerUnit: entry.input, gramsPerUnit: null, carbsPer100g: null, validUntil: 1000000 + WINDOW}});
    if (entry.delivery == null) await assert.rejects(promise, rejected);
    else {
      const {message} = await promise;
      assert.equal(message.treatment.carbs, entry.nutrition);
      assert.equal(message.treatment.deliveryCarbs, entry.delivery);
    }
  });
}

test('fractional declared conversion preserves the caregiver amount in the canonical child message', async () => {
  const {send, snapshot} = fixture();
  const {message} = await send({treatment: {...snapshot(), quantity: 1, gramsPerUnit: 10, carbsPer100g: 64.9, carbsPerUnit: 6.49}});
  assert.equal(message.treatment.carbs, 6.49);
  assert.equal(message.treatment.deliveryCarbs, 6);
  assert.equal(message.text, '1 × Candy · 6.49 g WW · zapis 6 g');
  await assert.rejects(send({treatment: {...snapshot(), quantity: 1, gramsPerUnit: 1, carbsPer100g: .5}}), rejected);
});

test('reference portions preserve declared carbs without inventing a physical weight', async () => {
  const {send} = fixture();
  const snapshot = {foodName: 'Reference snack', quantity: 2, unit: 'portion', carbsPerUnit: 4,
    gramsPerUnit: null, carbsPer100g: null, validUntil: 1000000 + WINDOW};
  const {message} = await send({treatment: snapshot});
  assert.equal(message.treatment.grams, null);
  assert.equal(message.treatment.carbs, 8);
  assert.equal(message.text, '2 × Reference snack · 8 g WW');
  for (const patch of [{gramsPerUnit: 100}, {carbsPer100g: 4}, {carbsPerUnit: 0}, {carbsPerUnit: Number.MIN_VALUE}, {quantity: Number.MIN_VALUE}]) {
    await assert.rejects(send({treatment: {...snapshot, ...patch}}), rejected);
  }
});

test('completion exposes a stable consumption result on the existing source, without creating another message after OFF', async () => {
  const {send, treatment, advance, store} = fixture();
  const {message} = await send();
  const proof = 'a'.repeat(43);
  const claim = await treatment.claim('child', {messageId: message.id, installationId: 'phone', proof, authorization});
  // A legacy OFF policy still suppresses follow-up messages on completion.
  store.values.set('families/one/chatConfig/current', {enabled: false, offGeneration: 1, revision: 1});
  assert.deepEqual(await treatment.complete('child', {claimId: claim.claimId, proof}), {ok: true});
  const ref = `families/one/chatMessages/${message.id}`;
  const completed = structuredClone(store.values.get(ref));
  assert.deepEqual(completed.treatmentResult, {uid: 'child', completedAt: 1000000, quantity: 2});
  assert.equal([...store.values.keys()].filter(path => path.startsWith('families/one/chatMessages/')).length, 1);
  advance(1000);
  await treatment.complete('child', {claimId: claim.claimId, proof});
  assert.deepEqual(store.values.get(ref), completed);
});

test('treatment freezes explicit portion conversion and never writes consumption on delivery/read', async () => {
  const {send, chat, store} = fixture();
  const {message} = await send();
  assert.equal(message.treatment.grams, 10);
  assert.equal(message.treatment.carbs, 8);
  assert.equal(message.text, '2 × Candy · 8 g WW');
  assert.equal(message.text.includes('Please eat'), false);
  await chat.acknowledge('child', {messageId: message.id, read: true});
  assert.equal([...store.values.keys()].some(path => path.startsWith('familyChatTreatmentClaims/')), false);
});

test('invalid portions, stale instructions and child-authored treatment are rejected', async () => {
  const {send, snapshot} = fixture();
  for (const patch of [{unit: 'tablet'}, {quantity: NaN}, {quantity: 0}, {quantity: Number.MIN_VALUE, gramsPerUnit: Number.MIN_VALUE}, {quantity: 0.00001}, {gramsPerUnit: -1}, {unit: 'g', gramsPerUnit: 5}, {carbsPer100g: 101}, {validUntil: 1}, {validUntil: 1000000 + WINDOW + 1}, {grams: 10}]) {
    await assert.rejects(fixture().send({treatment: {...snapshot(), ...patch}}), rejected);
  }
  await assert.rejects(send({}, 'child'), rejected);
  await assert.rejects(send({kind: 'text'}), rejected);
});

test('family treatment cannot omit a disabled child while another caregiver is active', async () => {
  const {store, send} = fixture();
  store.values.set('familyAccounts/dad', {familyId: 'one', role: 'managingCaregiver'});
  store.values.set('families/one/members/dad', {role: 'managingCaregiver', joinedAt: 1, invitationId: 'dad'});
  store.values.set('families/one', {childUid: 'child', memberUids: ['child', 'mom', 'dad'], managerUids: ['mom', 'dad']});
  store.values.set('familyChatAccounts/child', {enabled: false, revision: 1});
  await assert.rejects(send({targetUid: 'family'}), rejected);
  assert.equal([...store.values.keys()].some(path => path.startsWith('families/one/chatMessages/')), false);
});

test('competing child installations cannot transfer an ambiguous claim after its lease expires', async () => {
  const {send, treatment, advance} = fixture();
  const {message} = await send();
  const data = {messageId: message.id, installationId: 'device-one', proof: 'a'.repeat(43), authorization};
  const results = await Promise.allSettled([
    treatment.claim('child', data),
    treatment.claim('child', {...data, installationId: 'device-two', proof: 'b'.repeat(43)}),
  ]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  const first = results[0].value;
  advance(61000);
  await assert.rejects(treatment.claim('child', {...data, installationId: 'device-two'}), rejected);
  await assert.rejects(treatment.claim('child', {...data, proof: 'c'.repeat(43)}), rejected);
  const renewed = await treatment.claim('child', data);
  assert.equal(renewed.claimId, first.claimId);
  assert.ok(renewed.executionUntil > first.executionUntil);
});

test('claim requires current child, sender membership, enabled policy and unexpired instruction', async () => {
  for (const change of ['expiry', 'senderOff', 'senderEpoch', 'childOff', 'familyOff']) {
    const {send, treatment, advance, store} = fixture();
    const {message} = await send();
    if (change === 'expiry') advance(WINDOW);
    if (change === 'senderOff') store.values.set('familyChatAccounts/mom', {enabled: false, revision: 1});
    if (change === 'childOff') store.values.set('familyChatAccounts/child', {enabled: false, revision: 1});
    if (change === 'familyOff') store.values.set('families/one/chatConfig/current', {enabled: false, retention: 'week', revision: 1, shortenings: []});
    if (change === 'senderEpoch') store.values.set('families/one/members/mom', {role: 'managingCaregiver', joinedAt: 2, invitationId: 'new'});
    await assert.rejects(treatment.claim('child', {messageId: message.id, installationId: 'device', proof: 'a'.repeat(43), authorization}), rejected);
  }
});

test('already performed consumption can finalize minimally after expiry, OFF and unlink without exposing content', async () => {
  const {send, treatment, advance, store} = fixture();
  const {message} = await send();
  const data = {messageId: message.id, installationId: 'device', proof: 'a'.repeat(43), authorization};
  await assert.rejects(treatment.claim('mom', data), rejected);
  const claim = await treatment.claim('child', data);
  advance(WINDOW);
  store.values.delete('familyAccounts/child');
  store.values.delete(`families/one/chatMessages/${message.id}`);
  await assert.rejects(treatment.complete('mom', {claimId: claim.claimId, proof: data.proof}), rejected);
  await assert.rejects(treatment.complete('child', {claimId: claim.claimId, proof: 'b'.repeat(43)}), rejected);
  assert.deepEqual(await treatment.complete('child', {claimId: claim.claimId, proof: data.proof}), {ok: true});
  const saved = structuredClone(store.values.get(`familyChatTreatmentClaims/${claim.claimId}`));
  advance(1000);
  await treatment.complete('child', {claimId: claim.claimId, proof: data.proof});
  assert.deepEqual(store.values.get(`familyChatTreatmentClaims/${claim.claimId}`), saved);
  assert.equal(JSON.stringify(saved).includes('Candy'), false);
});
