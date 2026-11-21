'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {MemoryStore} = require('./memory_store.cjs');
const {createChatService, DAY} = require('../common/chat_service.cjs');
const {createChatNotifications} = require('../common/chat_notifications.cjs');
const {hash} = require('../common/security.cjs');

function fixture() {
  const store = new MemoryStore();
  let time = 1000000;
  const service = createChatService({store, now: () => time, signingKey: () => 'test-chat-signature'});
  for (const [fid, child, parents] of [['one', 'child', ['mom', 'dad']], ['two', 'other', ['stranger']]]) {
    store.values.set(`families/${fid}`, {childUid: child, memberUids: [child, ...parents], managerUids: parents});
    for (const uid of [child, ...parents]) {
      const role = uid === child ? 'child' : 'managingCaregiver';
      store.values.set(`familyAccounts/${uid}`, {familyId: fid, role});
      store.values.set(`families/${fid}/members/${uid}`, {role, invitationId: uid, joinedAt: 1, displayName: uid});
    }
  }
  const send = async (uid = 'mom', targetUid = 'child', extra = {}) => {
    const {tickets} = await service.reserve(uid, {count: 1});
    return service.send(uid, {ticket: tickets[0].token, targetUid, kind: 'text', text: 'Hello', ...extra});
  };
  return {store, service, send, advance: value => {time += value;}};
}
const denied = error => ['permission-denied', 'not-found', 'failed-precondition', 'invalid-argument', 'already-exists'].includes(error.code);

test('canonical unread covers uncached history, independent group reads and personal clear', async () => {
  const {service, send, advance} = fixture();
  const first = (await send()).message;
  for (let i = 0; i < 52; i++) {
    if (i % 8 === 0) advance(60001);
    const message = (await send()).message;
    await service.acknowledge('child', {messageId: message.id, read: true});
  }
  const summaries = () => service.conversations('child', {});
  let page = await summaries();
  assert.equal(page.familyId, 'one');
  assert.equal(page.historyGeneration, 0);
  assert.equal(page.conversations[0].hasUnread, true);
  assert.equal((await service.conversations('mom', {})).conversations[0].hasUnread, false);
  const group = (await send('mom', 'family')).message;
  await service.acknowledgeBatch('child', {items: [{messageId: first.id, read: true}]});
  page = await summaries();
  assert.equal(page.conversations.find(row => row.targetUid === 'mom').hasUnread, false);
  assert.equal(page.conversations.find(row => row.targetUid === 'family').hasUnread, true);
  await service.acknowledge('child', {messageId: group.id, read: true});
  assert.equal((await summaries()).conversations.find(row => row.targetUid === 'family').hasUnread, false);
  assert.equal((await service.conversations('dad', {})).conversations[0].hasUnread, true);
  await send();
  await service.clearHistory('child', {familyId: 'one', epoch: page.epoch, expectedGeneration: 0, operationId: 'unread-clear'});
  assert.ok((await summaries()).conversations.every(row => row.hasUnread === false));
  await send();
  assert.equal((await summaries()).conversations.find(row => row.targetUid === 'mom').hasUnread, true);
});

test('unread respects shortened effective expiry even after extension and marks legacy unknown', async () => {
  const {service, send, advance, store} = fixture();
  await service.configure('mom', {retention: 'unlimited', expectedRevision: 0});
  const old = (await send()).message;
  await service.configure('mom', {retention: 'day', expectedRevision: 1});
  await service.configure('mom', {retention: 'unlimited', expectedRevision: 2});
  advance(DAY);
  assert.equal((await service.conversations('child', {})).conversations[0].hasUnread, false);
  await send();
  assert.equal((await service.conversations('child', {})).conversations[0].hasUnread, true);
  const path = `families/one/chatConversations/${old.conversationId}`;
  const conversation = store.values.get(path);
  delete conversation.unreadIndexVersion;
  assert.equal((await service.conversations('child', {})).conversations[0].hasUnread, null);
  await send();
  assert.equal((await service.conversations('child', {})).conversations[0].hasUnread, null);
});

test('selected answers record their index, while identical manual text retains the legacy digest', async () => {
  const {service, store, send} = fixture();
  const {message: question} = await send('mom', 'child', {kind: 'question', answers: ['Yes', 'No']});
  const {tickets: [selectedTicket, manualTicket]} = await service.reserve('child', {count: 2});
  const body = {targetUid: 'mom', kind: 'answer', text: '  Yes  ', replyTo: question.id};

  const selected = {...body, ticket: selectedTicket.token, answerIndex: 0};
  const {message: indexedReply} = await service.send('child', selected);
  assert.equal(indexedReply.text, 'Yes');
  assert.equal(indexedReply.answerIndex, 0);
  assert.deepEqual((await service.send('child', {...selected, verifyOnly: true})).message, indexedReply);
  await assert.rejects(service.send('child', {...selected, answerIndex: 1}), error => error.code === 'already-exists');

  const manual = {...body, ticket: manualTicket.token};
  const {message: manualReply} = await service.send('child', manual);
  assert.equal(Object.hasOwn(manualReply, 'answerIndex'), false);
  const receipt = store.values.get(`families/one/chatOperationReceipts/${manualTicket.id}`);
  assert.equal(receipt.digest, hash(JSON.stringify(['mom', 'answer', 'Yes', [], question.id, null])));
  assert.deepEqual((await service.send('child', {...manual, verifyOnly: true})).message, manualReply);
  await assert.rejects(service.send('child', {...manual, answerIndex: 0}), error => error.code === 'already-exists');

  const {messages} = await service.states('mom', {ids: [indexedReply.id, manualReply.id]});
  assert.equal(messages.find(message => message.id === indexedReply.id).answerIndex, 0);
  assert.equal(Object.hasOwn(messages.find(message => message.id === manualReply.id), 'answerIndex'), false);
});

test('historical options with surrounding whitespace remain selectable and retryable', async () => {
  const {service, send} = fixture();
  const {message: question} = await send('mom', 'child', {kind: 'question', answers: [' Yes ']});
  const {tickets} = await service.reserve('child', {count: 1});
  const body = {ticket: tickets[0].token, targetUid: 'mom', kind: 'answer', text: ' Yes ', replyTo: question.id, answerIndex: 0};
  const {message} = await service.send('child', body);
  assert.equal(message.text, 'Yes');
  assert.equal(message.answerIndex, 0);
  assert.deepEqual((await service.send('child', {...body, verifyOnly: true})).message, message);
});

test('selected answer indices require a visible question and exact option text', async () => {
  const {service, send} = fixture();
  const {message: question} = await send('mom', 'child', {kind: 'question', answers: ['Yes']});
  const {message: comment} = await send();
  const {tickets: [ticket]} = await service.reserve('child', {count: 1});
  const body = {ticket: ticket.token, targetUid: 'mom', kind: 'answer', text: 'Yes', replyTo: question.id, answerIndex: 0};
  for (const patch of [
    {answerIndex: -1},
    {answerIndex: 6},
    {answerIndex: 0.5},
    {answerIndex: '0'},
    {answerIndex: null},
    {kind: 'text'},
    {replyTo: undefined},
    {replyTo: null},
    {replyTo: comment.id},
    {answerIndex: 1},
    {text: 'No'},
  ]) {
    await assert.rejects(service.send('child', {...body, ...patch}), error => error.code === 'invalid-argument');
  }
  await assert.rejects(service.send('child', {...body, replyTo: 'missing'}), error => error.code === 'not-found');
  await assert.rejects(service.send('child', {...body, targetUid: 'family'}), error => error.code === 'not-found');
  assert.equal((await service.send('child', body)).message.answerIndex, 0);
});

test('clear receipts distinguish lost replies from another device gesture and cannot re-clear after receipt expiry', async () => {
  const {service, send, store} = fixture();
  const epoch = (await service.getConfig('child', {})).epoch;
  const a = {familyId: 'one', epoch, expectedGeneration: 0, operationId: 'device-a'};
  const b = {...a, operationId: 'device-b'};
  await service.clearHistory('child', a);
  const next = (await send()).message;
  await assert.rejects(service.clearHistory('child', b), e => e.code === 'already-exists');
  assert.equal((await service.states('child', {ids: [next.id]})).messages.length, 1);
  await service.clearHistory('child', {...b, expectedGeneration: 1});
  const afterB = (await send()).message;
  assert.deepEqual(await service.clearHistory('child', a), {generation: 1});
  assert.equal((await service.states('child', {ids: [afterB.id]})).messages.length, 1);
  await assert.rejects(service.clearHistory('child', {...a, expectedGeneration: 2}), e => e.code === 'already-exists');
  const path = `families/one/chatOperationReceipts/clear_${hash('child:device-a')}`;
  assert.ok(store.values.get(path).deleteAfter instanceof Date);
  store.values.delete(path);
  await assert.rejects(service.clearHistory('child', a), e => e.code === 'already-exists');
  assert.equal((await service.states('child', {ids: [afterB.id]})).messages.length, 1);
});

test('personal history clear hides only the owner, survives retries and preserves newer group messages', async () => {
  const {service, send, store} = fixture();
  assert.equal((await service.getConfig('child', {})).historyGeneration, 0);
  const epoch = (await service.getConfig('child', {})).epoch;
  const first = (await send('mom', 'family')).message;
  const heldTicket = (await service.reserve('child', {count: 1})).tickets[0];
  const before = (await service.getConfig('child', {})).account;
  assert.deepEqual(await service.clearHistory('child', {expectedGeneration: 0, epoch, familyId: 'one', operationId: 'clear-one'}), {generation: 1});
  assert.equal((await service.getConfig('child', {})).historyGeneration, 1);
  assert.equal((await service.getConfig('dad', {})).historyGeneration, 0);
  assert.equal((await service.states('child', {ids: [first.id]})).messages.length, 0);
  assert.equal((await service.fetch('child', {targetUid: 'family', latest: true})).messages.length, 0);
  assert.equal((await service.states('dad', {ids: [first.id]})).messages.length, 1);
  await assert.rejects(service.acknowledge('child', {messageId: first.id, read: true}), e => e.code === 'not-found');
  await assert.rejects(send('child', 'family', {kind: 'answer', replyTo: first.id}), e => e.code === 'not-found');
  const second = (await service.send('child', {ticket: heldTicket.token, targetUid: 'family', kind: 'text', text: 'New text'})).message;
  assert.equal(second.historyGeneration, 1);
  assert.equal(second.historyGenerations, undefined);
  await service.clearHistory('child', {expectedGeneration: 0, epoch, familyId: 'one', operationId: 'clear-one'});
  assert.equal((await service.states('child', {ids: [second.id]})).messages.length, 1);
  const after = (await service.getConfig('child', {})).account;
  assert.equal(after.revision, before.revision);
  assert.equal(after.offGeneration, before.offGeneration);
  await service.configure('child', {accountEnabled: false, expectedRevision: 0});
  await service.configure('child', {accountEnabled: true, expectedRevision: 1});
  assert.equal((await service.states('child', {ids: [first.id]})).messages.length, 0);
  assert.ok(store.values.get(`families/one/chatMessages/${first.id}`));
  await assert.rejects(service.clearHistory('child', {expectedGeneration: 10, epoch, familyId: 'one', operationId: 'future'}), e => e.code === 'already-exists');
  await assert.rejects(service.clearHistory('child', {expectedGeneration: 1, uid: 'dad', epoch, familyId: 'one', operationId: 'override'}), e => e.code === 'invalid-argument');
});

test('history generation covers legacy bodies and more than thirty former direct conversations', async () => {
  const {service, send, store} = fixture();
  const epoch = (await service.getConfig('child', {})).epoch;
  const first = (await send()).message;
  const ids = [];
  for (let index = 0; index < 40; index++) {
    const id = `historical_${index}`;
    const legacy = {...first, id, conversationId: `former_${index}`};
    delete legacy.historyGenerations;
    store.values.set(`families/one/chatMessages/${id}`, legacy);
    ids.push(id);
  }
  assert.equal((await service.states('child', {ids})).messages.length, 40);
  await service.clearHistory('child', {expectedGeneration: 0, epoch, familyId: 'one', operationId: 'clear-one'});
  assert.equal((await service.states('child', {ids})).messages.length, 0);
  assert.equal((await service.states('mom', {ids})).messages.length, 40);
  const member = store.values.get('families/one/members/child');
  store.values.set('families/one/members/child', {...member, joinedAt: 2});
  const next = (await send()).message;
  assert.equal((await service.states('child', {ids: [next.id]})).messages[0].historyGeneration, 0);
  assert.equal((await service.states('child', {ids: [next.id]})).messages.length, 1);
  await assert.rejects(service.clearHistory('child', {expectedGeneration: 0, epoch, familyId: 'one', operationId: 'clear-one'}), e => e.code === 'failed-precondition');
  await service.clearHistory('child', {expectedGeneration: 0, epoch: (await service.getConfig('child', {})).epoch, familyId: 'one', operationId: 'clear-two'});
  assert.equal((await service.states('child', {ids: [next.id]})).messages.length, 0);
});

test('identical membership epochs never carry history clearing into another family', async () => {
  const {service, send, store} = fixture();
  const epoch = (await service.getConfig('child', {})).epoch;
  await service.clearHistory('child', {familyId: 'one', epoch, expectedGeneration: 0, operationId: 'clear-one'});
  store.values.set('families/two', {childUid: 'child', memberUids: ['child', 'stranger'], managerUids: ['stranger']});
  store.values.set('familyAccounts/child', {familyId: 'two', role: 'child'});
  store.values.set('families/two/members/child', {...store.values.get('families/one/members/child')});
  assert.equal((await service.getConfig('child', {})).epoch, epoch);
  await assert.rejects(service.clearHistory('child', {familyId: 'one', epoch, expectedGeneration: 0, operationId: 'clear-one'}), e => e.code === 'failed-precondition');
  const next = (await send('stranger', 'child')).message;
  const visible = (await service.states('child', {ids: [next.id]})).messages;
  assert.equal(visible.length, 1);
  assert.equal(visible[0].historyGeneration, 0);
  assert.equal(visible[0].historyGenerations, undefined);
  await service.clearHistory('child', {familyId: 'two', epoch, expectedGeneration: 0, operationId: 'clear-two'});
  assert.equal((await service.states('child', {ids: [next.id]})).messages.length, 0);
});

test('lost send response resolves the same operation after policy revisions without creating another message', async () => {
  const {service, store} = fixture();
  const ticket = (await service.reserve('mom', {count: 1})).tickets[0];
  const data = {ticket: ticket.token, targetUid: 'child', kind: 'text', text: 'One message'};
  const first = await service.send('mom', data);
  await service.configure('mom', {retention: 'month', expectedRevision: 0});
  const verified = await service.send('mom', {...data, verifyOnly: true});
  assert.equal(verified.message.id, first.message.id);
  assert.equal(verified.message.sequence, 1);
  assert.equal([...store.values.keys()].filter(key => key.includes('/chatMessages/')).length, 1);
});

test('verification never creates a message, even with a fresh ticket and no committed receipt', async () => {
  const {service, store} = fixture();
  const ticket = (await service.reserve('mom', {count: 1})).tickets[0];
  const data = {ticket: ticket.token, targetUid: 'child', kind: 'text', text: 'No send'};
  await assert.rejects(service.send('mom', {...data, verifyOnly: true}), error => error.details?.reason === 'chat-send-outcome-unknown');
  assert.equal([...store.values.keys()].filter(key => key.includes('/chatMessages/')).length, 0);
  assert.ok((await service.send('mom', data)).message);
});

test('stale tickets remain outcome-unknown when receipt or visible body is unavailable', async () => {
  for (const missing of ['body', 'receipt', 'both']) {
    const {service, store, advance} = fixture();
    const ticket = (await service.reserve('mom', {count: 1})).tickets[0];
    const data = {ticket: ticket.token, targetUid: 'child', kind: 'text', text: 'Old send'};
    const first = await service.send('mom', data);
    advance(3 * DAY);
    if (missing !== 'receipt') store.values.delete(`families/one/chatMessages/${first.message.id}`);
    if (missing !== 'body') store.values.delete(`families/one/chatOperationReceipts/${first.message.id}`);
    await assert.rejects(service.send('mom', {...data, verifyOnly: true}), error => error.details?.reason === 'chat-send-outcome-unknown');
  }
});

test('ticket outcome reasons never bypass forged signature, another UID, or account OFF', async () => {
  const {service} = fixture();
  const ticket = (await service.reserve('mom', {count: 1})).tickets[0];
  const data = {ticket: ticket.token, targetUid: 'child', kind: 'text', text: 'No disclosure', verifyOnly: true};
  await assert.rejects(service.send('mom', {...data, ticket: ticket.token + 'forged'}), error => error.details === undefined);
  await assert.rejects(service.send('dad', data), error => error.details === undefined);
  await service.configure('mom', {accountEnabled: false, expectedRevision: 0});
  await assert.rejects(service.send('mom', data), error => error.code === 'failed-precondition' && error.details === undefined);
});

test('public chat configuration rejects familyEnabled for every role and request shape', async () => {
  const {service, store} = fixture();
  const family = store.values.get('families/one');
  for (const [uid, memberUids, managerUids] of [
    ['mom', family.memberUids, family.managerUids],
    ['child', family.memberUids, family.managerUids],
    ['child', ['child'], []],
  ]) {
    store.values.set('families/one', {...family, memberUids, managerUids});
    for (const [familyEnabled, update] of [
      [false, {}],
      [true, {accountEnabled: false}],
      [false, {retention: 'day'}],
      [true, {initializeIfAbsent: true, retention: 'day'}],
    ]) {
      await assert.rejects(
        service.configure(uid, {familyEnabled, expectedRevision: 0, ...update}),
        error => error.code === 'invalid-argument',
      );
    }
  }
  store.values.set('families/one', family);
  await assert.rejects(
    service.configure('mom', {accountEnabled: false, retention: 'day', expectedRevision: 0}),
    error => error.code === 'invalid-argument',
  );
  assert.equal(store.values.has('families/one/chatConfig/current'), false);
  assert.equal((await service.getConfig('child', {})).account.enabled, true);
  assert.equal(store.values.has('familyChatAccounts/mom'), false);
});

test('account OFF generation survives ON and retention edits preserve legacy family OFF', async () => {
  const {service, store, send} = fixture();
  let config = await service.getConfig('child', {});
  assert.equal(config.account.offGeneration, 0);
  assert.equal(config.policy.offGeneration, 0);
  assert.equal(config.policyConfigured, false);
  await service.configure('child', {accountEnabled: false, expectedRevision: 0});
  await service.configure('child', {accountEnabled: false, expectedRevision: 1});
  await service.configure('child', {accountEnabled: true, expectedRevision: 2});
  config = await service.getConfig('child', {});
  assert.equal(config.account.offGeneration, 1);
  const {tickets} = await service.reserve('mom', {count: 1});
  const data = {ticket: tickets[0].token, targetUid: 'child', kind: 'text', text: 'Old send'};
  // A saved policy from before the public family toggle was retired.
  const policyPath = 'families/one/chatConfig/current';
  store.values.set(policyPath, {...config.policy, enabled: false, offGeneration: 1, revision: 1});
  await service.configure('mom', {retention: 'day', expectedRevision: 1});
  config = await service.getConfig('child', {});
  assert.equal(config.policy.enabled, false);
  assert.equal(config.policy.retention, 'day');
  assert.equal(config.policy.offGeneration, 1);
  assert.equal(config.account.offGeneration, 1);
  await assert.rejects(service.send('mom', data), error => error.code === 'failed-precondition' && error.details === undefined);
  // Simulate a policy that the old server had already re-enabled.
  store.values.set(policyPath, {...config.policy, enabled: true, revision: 3});
  await assert.rejects(service.send('mom', data), error => error.details?.reason === 'chat-send-outcome-unknown');
  assert.ok((await send()).message);
  assert.equal(config.policyConfigured, true);
  assert.equal((await service.getConfig('mom', {})).account.offGeneration, 0);
});

test('founder setup initializes absent policy once and never overwrites an existing family choice', async () => {
  const {service, store} = fixture();
  await assert.rejects(service.configure('mom', {initializeIfAbsent: true, retention: 'day', expectedRevision: 0}), denied);
  await assert.rejects(service.configure('child', {initializeIfAbsent: true, retention: 'day', expectedRevision: 0}), denied);
  const family = store.values.get('families/one');
  store.values.set('families/one', {...family, memberUids: ['child'], managerUids: []});
  const results = await Promise.all([
    service.configure('child', {initializeIfAbsent: true, retention: 'day', expectedRevision: 0}),
    service.configure('child', {initializeIfAbsent: true, retention: 'month', expectedRevision: 0}),
  ]);
  assert.equal(results.filter(result => result.initialized === true).length, 1);
  assert.equal(results.filter(result => result.initialized === false).length, 1);
  let config = await service.getConfig('child', {});
  assert.equal(config.policy.retention, 'day');
  assert.equal(config.policy.enabled, true);
  assert.equal(config.policy.offGeneration, 0);
  store.values.set('families/one', family);
  assert.deepEqual(await service.configure('mom', {initializeIfAbsent: true, retention: 'unlimited', expectedRevision: 0}), {ok: true, initialized: false});
  config = await service.getConfig('mom', {});
  assert.equal(config.policy.retention, 'day');
  assert.equal(config.policy.enabled, true);
});

test('installation counters prevent a late old-account registration from replacing the new binding', async () => {
  const {store, service} = fixture();
  const notifications = createChatNotifications({store, chat: service, messaging: {}});
  const data = {token: 'shared-physical-device-token', enabled: true, installationId: 'a'.repeat(43), revocationToken: 'b'.repeat(43), counter: 1};
  await notifications.register('child', data);
  await notifications.register('mom', {...data, counter: 3});
  await assert.rejects(notifications.register('child', {...data, counter: 2}), denied);
  await assert.rejects(notifications.register('child', {...data, counter: 2, enabled: false}), denied);
  await notifications.register('mom', {...data, counter: 3});
  assert.equal(store.values.get(`familyChatDevices/${hash(data.token)}`).uid, 'mom');
});

test('device capability revokes after signout, waits for an uncertain registration, and cannot remove a newer binding', async () => {
  const {store, service} = fixture();
  const notifications = createChatNotifications({store, chat: service, messaging: {}});
  const data = {token: 'shared-physical-device-token', enabled: true, installationId: 'a'.repeat(43), revocationToken: 'b'.repeat(43), counter: 1};
  const capability = ({enabled, ...value}) => value;
  assert.deepEqual(await notifications.revoke(capability(data)), {pending: true});
  await notifications.register('child', data);
  await assert.rejects(notifications.revoke({...capability(data), revocationToken: 'x'.repeat(43)}), denied);
  await notifications.revoke(capability(data));
  assert.equal(store.values.has(`familyChatDevices/${hash(data.token)}`), false);
  await notifications.register('child', data);
  assert.equal(store.values.has(`familyChatDevices/${hash(data.token)}`), false);
  await notifications.register('mom', {...data, counter: 2, revocationToken: 'c'.repeat(43)});
  await notifications.revoke(capability(data));
  assert.equal(store.values.get(`familyChatDevices/${hash(data.token)}`).uid, 'mom');
});

test('chat push dispatch sends opaque IDs once and does not manufacture a delivery receipt', async () => {
  const {store, service, send} = fixture();
  const delivered = [];
  const notifications = createChatNotifications({store, chat: service, now: () => 1000000, messaging: {sendEachForMulticast: async value => {delivered.push(value); return {responses: value.tokens.map(() => ({success: true}))};}}});
  await notifications.register('child', {enabled: true, token: 'child-notification-token'});
  const {message} = await send();
  const job = hash(`${message.id}:child`);
  await notifications.dispatch(job);
  await notifications.dispatch(job);
  assert.equal(delivered.length, 1);
  assert.deepEqual(Object.keys(delivered[0].data).sort(), ['epoch', 'familyId', 'messageId', 'type', 'uid']);
  assert.equal(delivered[0].apns.headers['apns-push-type'], 'alert');
  assert.equal(delivered[0].apns.headers['apns-expiration'], String((1000000 + delivered[0].android.ttl) / 1000));
  assert.deepEqual(delivered[0].apns.payload.aps.alert, {title: 'Diabeatthis', body: 'New family message'});
  assert.equal(JSON.stringify(delivered[0]).includes('Hello'), false);
  assert.equal((await service.states('mom', {ids: [message.id]})).messages[0].receipts.child.deliveredAt, null);
});

test('partial chat push retries only missing current bindings and a late error cannot delete a refreshed token', async () => {
  const {store, service, send} = fixture();
  const calls = [];
  let first = true;
  let refreshed = false;
  let notifications;
  notifications = createChatNotifications({store, chat: service, now: () => 1000000, messaging: {sendEachForMulticast: async value => {
    calls.push(value.tokens);
    if (first) {
      first = false;
      return {responses: value.tokens.map(token => token === 'child-device-one-token' ? {success: true} : {success: false, error: {code: 'messaging/internal-error'}})};
    }
    // Re-register at exactly the same clock instant before the old response.
    if (!refreshed) {
      refreshed = true;
      await notifications.register('child', {enabled: true, token: 'child-device-two-token'});
      return {responses: [{success: false, error: {code: 'messaging/registration-token-not-registered'}}]};
    }
    return {responses: [{success: true}]};
  }}});
  await notifications.register('child', {enabled: true, token: 'child-device-one-token'});
  await notifications.register('child', {enabled: true, token: 'child-device-two-token'});
  const {message} = await send();
  const job = hash(`${message.id}:child`);
  await assert.rejects(notifications.dispatch(job));
  await assert.rejects(notifications.dispatch(job));
  assert.equal(store.values.get(`familyChatNotificationJobs/${job}`).status, 'pending');
  await notifications.dispatch(job);
  assert.equal(calls[0].length, 2);
  assert.deepEqual(calls[1], ['child-device-two-token']);
  assert.deepEqual(calls[2], ['child-device-two-token']);
  assert.equal(store.values.has(`familyChatDevices/${hash('child-device-two-token')}`), true);
});

test('a token rebound to another account between push retries receives no retry', async () => {
  const {store, service, send} = fixture();
  const calls = [];
  const notifications = createChatNotifications({store, chat: service, now: () => 1000000, messaging: {sendEachForMulticast: async value => {calls.push(value.tokens); return {responses: value.tokens.map(token => ({success: token === 'child-device-one-token', error: {code: 'messaging/internal-error'}}))};}}});
  await notifications.register('child', {enabled: true, token: 'child-device-one-token'});
  await notifications.register('child', {enabled: true, token: 'child-device-two-token'});
  const {message} = await send();
  const id = hash(`${message.id}:child`);
  await assert.rejects(notifications.dispatch(id));
  await notifications.register('mom', {enabled: true, token: 'child-device-two-token'});
  await notifications.dispatch(id);
  assert.equal(calls.length, 1);
});

test('device cleanup failure preserves successful push acceptance markers', async () => {
  const {store, service, send} = fixture();
  const run = store.runTransaction.bind(store);
  let failCleanup = false;
  store.runTransaction = action => run(tx => action({...tx, get: async ref => {
    if (failCleanup && ref.path === `familyChatDevices/${hash('child-device-two-token')}`) { failCleanup = false; throw new Error('Injected cleanup failure'); }
    return tx.get(ref);
  }}));
  const calls = [];
  const notifications = createChatNotifications({store, chat: service, now: () => 1000000, messaging: {sendEachForMulticast: async value => {
    calls.push(value.tokens);
    if (calls.length === 1) { failCleanup = true; return {responses: [{success: true}, {success: false, error: {code: 'messaging/invalid-registration-token'}}]}; }
    return {responses: value.tokens.map(() => ({success: true}))};
  }}});
  await notifications.register('child', {enabled: true, token: 'child-device-one-token'});
  await notifications.register('child', {enabled: true, token: 'child-device-two-token'});
  const {message} = await send();
  const id = hash(`${message.id}:child`);
  await assert.rejects(notifications.dispatch(id));
  assert.equal(store.values.get(`familyChatNotificationJobs/${id}`).completed.length, 1);
  await notifications.dispatch(id);
  assert.deepEqual(calls[1], ['child-device-two-token']);
});

for (const revoke of ['off', 'familyOff', 'rejoin', 'unlink', 'expired', 'senderOff']) {
  test(`chat push revalidates authorization immediately before dispatch: ${revoke}`, async () => {
    const {store, service, send, advance} = fixture();
    let delivered = false;
    const notifications = createChatNotifications({store, chat: service, now: () => revoke === 'expired' ? 1000000 + 8 * DAY : 1000000, messaging: {sendEachForMulticast: async () => {delivered = true; return {responses: [{success: true}]};}}});
    await notifications.register('child', {enabled: true, token: 'child-notification-token'});
    const {message} = await send();
    if (revoke === 'off') await service.configure('child', {accountEnabled: false, expectedRevision: 0});
    if (revoke === 'familyOff') {
      // Legacy family OFF must still stop delivery of previously queued jobs.
      store.values.set('families/one/chatConfig/current', {enabled: false, offGeneration: 1, revision: 1});
    }
    if (revoke === 'senderOff') await service.configure('mom', {accountEnabled: false, expectedRevision: 0});
    if (revoke === 'rejoin') store.values.set('families/one/members/child', {role: 'child', invitationId: 'new', joinedAt: 2});
    if (revoke === 'unlink') store.values.delete('familyAccounts/child');
    if (revoke === 'expired') advance(8 * DAY);
    await notifications.dispatch(hash(`${message.id}:child`));
    assert.equal(delivered, false);
  });
}

test('chat token account rebinding cannot be removed by the old owner', async () => {
  const {store, service} = fixture();
  const notifications = createChatNotifications({store, chat: service, messaging: {}});
  const data = {enabled: true, token: 'shared-device-token-123'};
  await notifications.register('child', data);
  await notifications.register('mom', data);
  await notifications.register('child', {...data, enabled: false});
  assert.equal(store.values.get(`familyChatDevices/${hash(data.token)}`).uid, 'mom');
  await assert.rejects(notifications.register('pending', data), denied);
});

test('transient chat push retry keeps the durable job and invalid token cleanup is scoped', async () => {
  const {store, service, send} = fixture();
  let attempts = 0;
  const notifications = createChatNotifications({store, chat: service, now: () => 1000000, messaging: {sendEachForMulticast: async () => {attempts++; return {responses: [{success: false, error: {code: attempts === 1 ? 'messaging/internal-error' : 'messaging/registration-token-not-registered'}}]};}}});
  const token = 'child-notification-token';
  await notifications.register('child', {enabled: true, token});
  const {message} = await send();
  const id = hash(`${message.id}:child`);
  await assert.rejects(notifications.dispatch(id));
  assert.equal(store.values.get(`familyChatNotificationJobs/${id}`).status, 'pending');
  await notifications.dispatch(id);
  assert.equal(store.values.has(`familyChatDevices/${hash(token)}`), false);
  assert.equal(store.values.get(`familyChatNotificationJobs/${id}`).status, 'sent');
});

test('family questions are shared, reply library and wheel order stay private, revisions prevent resurrection', async () => {
  const {service, store} = fixture();
  const question = {id: 'breakfast', label: 'Śniadanie', text: 'Masz śniadanie?', emoji: '🥪', answers: ['Tak']};
  const reply = {id: 'yes', label: 'Tak', text: 'Tak!', emoji: '👍🏽', answers: []};
  await service.saveShortcuts('mom', {items: [question], expectedRevision: 0});
  assert.deepEqual((await service.shortcuts('dad', {})).items, [question]);
  assert.equal((await service.shortcuts('child', {})).items, null);
  await service.saveShortcuts('child', {items: [reply], expectedRevision: 0});
  await service.orderShortcuts('mom', {ids: ['breakfast'], expectedRevision: 0});
  assert.deepEqual((await service.shortcuts('dad', {})).order, []);
  await service.saveShortcuts('dad', {items: [], expectedRevision: 1});
  await assert.rejects(service.saveShortcuts('mom', {items: [question], expectedRevision: 1}), denied);
  await assert.rejects(service.orderShortcuts('mom', {ids: ['breakfast'], expectedRevision: 1}), denied);
  await assert.rejects(service.saveShortcuts('child', {items: [question], expectedRevision: 1}), denied);
  await assert.rejects(service.saveShortcuts('mom', {items: [{...question, emoji: 'two letters'}], expectedRevision: 2}), denied);
  await service.saveShortcuts('mom', {items: [{...question, label: '😀'.repeat(40)}], expectedRevision: 2});
  await assert.rejects(service.saveShortcuts('mom', {items: [{...question, label: '😀'.repeat(41)}], expectedRevision: 3}), denied);
  store.values.set('families/one/members/child', {role: 'child', invitationId: 'new', joinedAt: 2});
  assert.equal((await service.shortcuts('child', {})).items, null);
  await service.configure('mom', {accountEnabled: false, expectedRevision: 0});
  await assert.rejects(service.shortcuts('mom', {}), denied);
  assert.equal((await service.shortcuts('stranger', {})).items, null);
});

test('status refresh sees old receipt changes without revealing foreign IDs', async () => {
  const {service, send} = fixture();
  const first = (await send()).message;
  const foreign = (await send('stranger', 'other')).message;
  await service.acknowledgeBatch('child', {items: [{messageId: first.id, read: true}]});
  const result = await service.states('mom', {ids: [first.id, foreign.id, 'unknown']});
  assert.equal(result.messages.length, 1);
  assert.ok(result.messages[0].receipts.child.readAt);
  assert.deepEqual(result.missing, [foreign.id, 'unknown']);
  assert.equal((await service.fetch('mom', {targetUid: 'child', after: first.sequence})).messages.length, 0);
  await assert.rejects(service.states('mom', {ids: Array(51).fill('id')}), denied);
});

test('latest and older pages are bounded and indexed by actual recipient membership', async () => {
  const {service, send, advance} = fixture();
  for (let i = 0; i < 61; i++) {
    advance(60001);
    await send('child', 'family', {text: `message ${i}`});
  }
  const latest = await service.fetch('mom', {targetUid: 'family', latest: true});
  assert.equal(latest.messages.length, 50);
  assert.equal(latest.messages[0].sequence, 12);
  assert.equal(latest.cursor, 61);
  const older = await service.fetch('mom', {targetUid: 'family', before: latest.oldestCursor});
  assert.deepEqual(older.messages.map(row => row.sequence), Array.from({length: 11}, (_, i) => i + 1));
  assert.equal(older.hasMore, false);
  await service.configure('mom', {accountEnabled: false, expectedRevision: 0});
  for (let i = 0; i < 51; i++) { advance(60001); await send('child', 'family'); }
  await service.configure('mom', {accountEnabled: true, expectedRevision: 1});
  assert.equal((await service.fetch('mom', {targetUid: 'family', latest: true})).cursor, 61);
  await assert.rejects(service.fetch('mom', {targetUid: 'family', latest: true, after: 0}), denied);
});

test('batch ACK is own, monotonic and safely ignores unavailable messages', async () => {
  const {service, send, advance} = fixture();
  const a = (await send('child', 'family')).message;
  const b = (await send('mom', 'child')).message;
  const result = await service.acknowledgeBatch('mom', {items: [
    {messageId: a.id, read: true}, {messageId: b.id, read: true}, {messageId: 'unknown', read: false},
  ]});
  assert.deepEqual(result.acknowledged, [a.id]);
  assert.deepEqual(result.ignored, [b.id, 'unknown']);
  const before = (await service.states('child', {ids: [a.id]})).messages[0].receipts.mom;
  advance(10);
  await service.acknowledgeBatch('mom', {items: [{messageId: a.id, read: false}]});
  assert.deepEqual((await service.states('child', {ids: [a.id]})).messages[0].receipts.mom, before);
  await assert.rejects(service.acknowledgeBatch('mom', {items: [{messageId: a.id, read: true}, {messageId: a.id, read: false}]}), denied);
});

test('real recipient scope: child/direct and family messages, no cross-family or caregiver direct', async () => {
  const {service, send} = fixture();
  await send();
  assert.equal((await service.fetch('child', {targetUid: 'mom', after: 0})).messages.length, 1);
  assert.equal((await service.fetch('dad', {targetUid: 'child', after: 0})).messages.length, 0);
  await assert.rejects(send('mom', 'dad'), denied);
  await assert.rejects(send('stranger', 'child'), denied);
  await send('child', 'family');
  assert.equal((await service.fetch('mom', {targetUid: 'family', after: 0})).messages.length, 1);
  assert.equal((await service.fetch('dad', {targetUid: 'family', after: 0})).messages.length, 1);
});

test('operation ticket is bound to account, family, epoch and payload; concurrent retries create one message', async () => {
  const {store, service, advance} = fixture();
  const {tickets} = await service.reserve('mom', {count: 1});
  const data = {ticket: tickets[0].token, targetUid: 'child', kind: 'text', text: 'Hello'};
  const values = await Promise.all([service.send('mom', data), service.send('mom', data)]);
  assert.equal(values[0].message.id, values[1].message.id);
  assert.equal([...store.values.keys()].filter(key => key.includes('/chatMessages/')).length, 1);
  await assert.rejects(service.send('dad', data), denied);
  await assert.rejects(service.send('mom', {...data, text: 'Changed'}), denied);
  advance(DAY + 1);
  store.values.delete(`families/one/chatOperationReceipts/${tickets[0].id}`);
  await assert.rejects(service.send('mom', data), denied);
});

test('pending, revoked and rejoined members cannot read or ACK historic content', async () => {
  const {store, service, send} = fixture();
  const {message} = await send('child', 'family');
  await assert.rejects(service.getConfig('pending', {}), denied);
  store.values.delete('familyAccounts/mom');
  await assert.rejects(service.fetch('mom', {targetUid: 'family', after: 0}), denied);
  store.values.set('familyAccounts/mom', {familyId: 'one', role: 'managingCaregiver'});
  store.values.set('families/one/members/mom', {role: 'managingCaregiver', invitationId: 'new', joinedAt: 2});
  assert.equal((await service.fetch('mom', {targetUid: 'family', after: 0})).messages.length, 0);
  await assert.rejects(service.acknowledge('mom', {messageId: message.id, read: true}), denied);
});

test('account OFF excludes recipients, invalidates tickets and preserves unrelated family membership', async () => {
  const {store, service, send} = fixture();
  const {tickets} = await service.reserve('mom', {count: 1});
  await service.configure('mom', {accountEnabled: false, expectedRevision: 0});
  await assert.rejects(service.fetch('mom', {targetUid: 'family', after: 0}), denied);
  await assert.rejects(send('child', 'mom'), denied);
  const {message} = await send('child', 'family');
  assert.equal(message.participants.mom, undefined);
  await service.configure('mom', {accountEnabled: true, expectedRevision: 1});
  assert.equal((await service.fetch('mom', {targetUid: 'family', after: 0})).messages.length, 0);
  await assert.rejects(service.send('mom', {ticket: tickets[0].token, targetUid: 'child', kind: 'text', text: 'old'}), denied);
  assert.equal(store.values.get('familyAccounts/mom').familyId, 'one');
});

test('child retains direct history after caregiver leaves, revoked caregiver loses it', async () => {
  const {store, service, send} = fixture();
  await send('mom', 'child');
  store.values.delete('familyAccounts/mom');
  store.values.delete('families/one/members/mom');
  store.values.set('families/one', {childUid: 'child', memberUids: ['child', 'dad'], managerUids: ['dad']});
  assert.equal((await service.fetch('child', {targetUid: 'mom', after: 0})).messages.length, 1);
  const threads = await service.conversations('child', {});
  assert.equal(threads.conversations[0].targetUid, 'mom');
  assert.equal(threads.conversations[0].active, false);
  await assert.rejects(send('child', 'mom'), denied);
  await assert.rejects(service.fetch('mom', {targetUid: 'child', after: 0}), denied);
});

test('retention shortening cannot resurrect content when lengthened before cleanup', async () => {
  const {service, send, advance} = fixture();
  await service.configure('mom', {retention: 'month', expectedRevision: 0});
  await send();
  advance(2 * DAY);
  await service.configure('mom', {retention: 'day', expectedRevision: 1});
  await service.configure('mom', {retention: 'month', expectedRevision: 2});
  assert.equal((await service.fetch('child', {targetUid: 'mom', after: 0})).messages.length, 0);
  await assert.rejects(service.configure('child', {retention: 'unlimited', expectedRevision: 3}), denied);
  await assert.rejects(service.configure('dad', {retention: 'unlimited', expectedRevision: 0}), error => error.code === 'already-exists');
});

test('more than 128 retention changes remain usable and never restore an expired unlimited message', async () => {
  const {service, send, advance} = fixture();
  await service.configure('mom', {retention: 'unlimited', expectedRevision: 0});
  const message = await send();
  let revision = 1;
  for (let index = 0; index < 300; index++) {
    advance(60001); // Exercise the real rate limiter without bypassing it.
    await service.configure('mom', {retention: index % 2 === 0 ? 'day' : 'unlimited', expectedRevision: revision++});
    assert.ok((await service.getConfig('child', {})).policy.shortenings.length <= 3);
  }
  advance(2 * DAY);
  assert.deepEqual((await service.states('child', {ids: [message.message.id]})).messages, []);
  assert.deepEqual((await service.fetch('child', {targetUid: 'mom', latest: true})).messages, []);
});

test('inbox preserves earlier group rights while OFF and paginates more than thirty historic direct threads', async () => {
  const {store, service, send, advance} = fixture();
  await send('child', 'family');
  await service.configure('mom', {accountEnabled: false, expectedRevision: 0});
  await send('child', 'family');
  await service.configure('mom', {accountEnabled: true, expectedRevision: 1});
  assert.equal((await service.conversations('mom', {})).conversations[0].targetUid, 'family');
  for (let index = 0; index < 32; index++) {
    const uid = `historical${index}`;
    store.values.set(`familyAccounts/${uid}`, {familyId: 'one', role: 'managingCaregiver'});
    store.values.set(`families/one/members/${uid}`, {role: 'managingCaregiver', invitationId: uid, joinedAt: 1});
    store.values.set('families/one', {childUid: 'child', memberUids: ['child', uid], managerUids: [uid]});
    advance(60001);
    await send('child', uid);
  }
  const first = await service.conversations('child', {});
  assert.equal(first.conversations.length, 30);
  const second = await service.conversations('child', {after: first.cursor});
  assert.equal(second.conversations.length, 3);
  assert.equal(new Set([...first.conversations, ...second.conversations].map(row => row.id)).size, 33);
});

test('receipts are own, monotonic, visible only to participants, and never created by sending', async () => {
  const {service, send, advance} = fixture();
  const {message} = await send();
  assert.deepEqual(message.receipts.child, {deliveredAt: null, readAt: null});
  await assert.rejects(service.acknowledge('dad', {messageId: message.id, read: true}), denied);
  await service.acknowledge('child', {messageId: message.id, read: true});
  const first = (await service.fetch('mom', {targetUid: 'child', after: 0})).messages[0].receipts.child;
  advance(10);
  await service.acknowledge('child', {messageId: message.id, read: false});
  assert.deepEqual((await service.fetch('mom', {targetUid: 'child', after: 0})).messages[0].receipts.child, first);
});

test('validation rejects forged fields, blank or excessive suggested answers and invalid targets', async () => {
  const {service, send} = fixture();
  await assert.rejects(send('mom', 'child', {senderUid: 'dad'}), denied);
  await assert.rejects(send('mom', 'child', {kind: 'question', answers: ['']}), denied);
  await assert.rejects(send('mom', 'child', {text: ' '.repeat(3)}), denied);
  for (const answers of [[], ['Yes'], ['Yes', 'No']]) {
    const {message} = await send('mom', 'child', {kind: 'question', answers});
    assert.deepEqual(message.answers, answers);
  }
  await assert.rejects(service.fetch('child', {targetUid: 'mom', after: -1}), denied);
});
