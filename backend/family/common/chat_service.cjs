'use strict';
const {createHmac, randomUUID, timingSafeEqual} = require('node:crypto');
const {FamilyError, exact, hash} = require('./security.cjs');
const {treatmentSnapshot, treatmentText, treatmentWithQuantity} = require('./chat_treatment.cjs');
const {compactShortenings} = require('./chat_retention.cjs');
const DAY = 86400000;
const PERIODS = {day: 1, week: 7, month: 30, unlimited: null};
const fail = code => { throw new FamilyError(code); };
const identifier = value => {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) fail('invalid-argument');
  return value;
};
const epoch = member => hash(JSON.stringify([member.invitationId ?? '', member.joinedAt ?? 0]));
const defaultPolicy = () => ({enabled: true, retention: 'week', revision: 0, offGeneration: 0, shortenings: []});
const graphemes = new Intl.Segmenter('und', {granularity: 'grapheme'});
const textWithin = (value, max) => typeof value === 'string' && value.trim() && value.length <= max * 32 && [...graphemes.segment(value)].length <= max;

function createChatService({store, now = Date.now, signingKey = () => process.env.PAIRING_HMAC_KEY}) {
  const doc = path => store.doc(path);
  const root = fid => `families/${fid}`;
  const configRef = fid => doc(`${root(fid)}/chatConfig/current`);
  const messages = fid => store.collection(`${root(fid)}/chatMessages`);
  const preferenceRef = uid => doc(`familyChatAccounts/${uid}`);
  const inbox = (fid, uid, membershipEpoch) => store.collection(`${root(fid)}/chatInboxes/${hash(`${uid}:${membershipEpoch}`)}/threads`);
  const messageIndex = (fid, uid, membershipEpoch) => store.collection(`${root(fid)}/chatInboxes/${hash(`${uid}:${membershipEpoch}`)}/chatMessageIndex`);
  const read = async (tx, ref) => (await tx.get(ref)).data();
  async function rate(uid, action, limit) {
    const ref = doc(`familyRateLimits/${hash(`chat:${uid}:${action}`)}`);
    await store.runTransaction(async tx => {
      const old = await read(tx, ref), time = now();
      const current = old && old.start + 60000 > time;
      const count = current ? old.count + 1 : 1;
      if (count > limit) fail('resource-exhausted');
      tx.set(ref, {start: current ? old.start : time, count, deleteAfter: new Date(time + DAY)});
    });
  }
  async function scope(tx, uid, enabled = true) {
    const account = await read(tx, doc(`familyAccounts/${uid}`));
    if (!account?.familyId) fail('permission-denied');
    const fid = identifier(account.familyId);
    const family = await read(tx, doc(root(fid)));
    if (!family || !Array.isArray(family.memberUids) || family.memberUids.length > 6 || !family.memberUids.includes(uid)) fail('permission-denied');
    const members = {}, preferences = {};
    for (const memberUid of family.memberUids) {
      identifier(memberUid);
      const member = await read(tx, doc(`${root(fid)}/members/${memberUid}`));
      const binding = await read(tx, doc(`familyAccounts/${memberUid}`));
      if (!member || binding?.familyId !== fid || binding.role !== member.role ||
        (member.role === 'child' ? family.childUid !== memberUid : member.role !== 'managingCaregiver' || !family.managerUids?.includes(memberUid))) fail('permission-denied');
      members[memberUid] = {...member, epoch: epoch(member)};
      preferences[memberUid] = {enabled: true, revision: 0, offGeneration: 0, ...await read(tx, preferenceRef(memberUid))};
    }
    if (members[uid]?.role !== account.role) fail('permission-denied');
    const savedPolicy = await read(tx, configRef(fid));
    const policy = {...defaultPolicy(), ...savedPolicy};
    if (enabled && (!policy.enabled || !preferences[uid].enabled)) fail('failed-precondition');
    return {fid, family, members, preferences, policy, policyConfigured: savedPolicy != null};
  }
  function target(state, uid, targetUid, history = false) {
    if (targetUid === 'family') return {id: 'family', candidates: Object.keys(state.members).filter(id => id !== uid)};
    identifier(targetUid);
    if (targetUid === uid || !history && !state.members[targetUid] || (uid !== state.family.childUid && targetUid !== state.family.childUid)) fail('permission-denied');
    return {id: `direct_${hash([uid, targetUid].sort().join(':'))}`, candidates: [targetUid]};
  }
  function expiresAt(message, policy) {
    let expires = message.expiresAt;
    for (const change of policy.shortenings ?? []) {
      if (message.policyRevision < change.revision) {
        const shortened = message.sentAt + change.days * DAY;
        expires = expires == null ? shortened : Math.min(expires, shortened);
      }
    }
    return expires;
  }
  function historyGeneration(state, uid) {
    const preference = state.preferences[uid];
    return preference.historyFamilyId === state.fid && preference.historyEpoch === state.members[uid].epoch ? preference.historyGeneration ?? 0 : 0;
  }
  function visible(message, state, uid) {
    const expiry = expiresAt(message, state.policy);
    return message.participants?.[uid] === state.members[uid].epoch &&
      (message.historyGenerations?.[uid] ?? 0) === historyGeneration(state, uid) && (expiry == null || expiry > now());
  }
  function publicMessage(message, policy, uid) {
    const {digest, historyGenerations, ...value} = message;
    return {...value, historyGeneration: historyGenerations?.[uid] ?? 0, expiresAt: expiresAt(message, policy)};
  }
  function sign(payload) {
    const key = signingKey();
    if (!key) fail('internal');
    return createHmac('sha256', key).update(payload).digest('base64url');
  }
  function ticket(value, state, uid) {
    if (typeof value !== 'string' || value.length > 2048) fail('invalid-argument');
    const parts = value.split('.');
    if (parts.length !== 2) fail('invalid-argument');
    const expected = Buffer.from(sign(parts[0]));
    const signature = Buffer.from(parts[1]);
    if (signature.length !== expected.length || !timingSafeEqual(signature, expected)) fail('permission-denied');
    let data;
    try { data = JSON.parse(Buffer.from(parts[0], 'base64url').toString()); } catch (_) { fail('invalid-argument'); }
    if (data.uid !== uid) fail('permission-denied');
    if (!Number.isSafeInteger(data.until) || data.until < 0 || !Number.isSafeInteger(data.version) || data.version < 0 ||
        !Number.isSafeInteger(data.policyVersion) || data.policyVersion < 0) fail('invalid-argument');
    identifier(data.fid); identifier(data.epoch);
    identifier(data.id);
    return {...data, stale: data.fid !== state.fid || data.epoch !== state.members[uid].epoch ||
      data.version !== state.preferences[uid].revision || data.policyVersion !== state.policy.revision || data.until <= now()};
  }
  const unknownOutcome = () => { throw new FamilyError('failed-precondition', undefined, {reason: 'chat-send-outcome-unknown'}); };
  async function getConfig(uid, data) {
    exact(data, []); await rate(uid, 'config', 60);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid, false);
      return {familyId: state.fid, uid, epoch: state.members[uid].epoch,
        historyGeneration: historyGeneration(state, uid),
        account: state.preferences[uid], policy: state.policy, policyConfigured: state.policyConfigured, serverTime: now(),
        canManage: state.members[uid].role === 'managingCaregiver' || state.family.managerUids.length === 0 && state.family.childUid === uid,
        members: Object.entries(state.members).map(([id, member]) => ({uid: id, displayName: member.displayName ?? '', photoUrl: member.photoUrl ?? null, role: member.role, epoch: member.epoch, enabled: state.preferences[id].enabled}))};
    });
  }
  async function configure(uid, data) {
    exact(data, ['accountEnabled', 'retention', 'expectedRevision', 'initializeIfAbsent']);
    if (!Number.isSafeInteger(data.expectedRevision) || data.expectedRevision < 0 ||
      data.accountEnabled !== undefined && typeof data.accountEnabled !== 'boolean' ||
      data.retention !== undefined && !Object.hasOwn(PERIODS, data.retention) ||
      data.initializeIfAbsent !== undefined && data.initializeIfAbsent !== true ||
      data.initializeIfAbsent === true && (data.accountEnabled !== undefined || data.expectedRevision !== 0)) fail('invalid-argument');
    await rate(uid, 'configure', 10);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid, false);
      if (data.initializeIfAbsent === true) {
        if (state.policyConfigured) return {ok: true, initialized: false};
        if (uid !== state.family.childUid || state.family.managerUids.length !== 0) fail('permission-denied');
      }
      const ownOnly = data.retention === undefined && data.initializeIfAbsent !== true;
      if (!ownOnly && state.members[uid].role !== 'managingCaregiver' && !(state.family.childUid === uid && state.family.managerUids.length === 0)) fail('permission-denied');
      const previous = ownOnly ? state.preferences[uid] : state.policy;
      if (previous.revision !== data.expectedRevision) fail('already-exists');
      if (data.accountEnabled !== undefined) {
        // Account and family policy updates use separate revisions/requests.
        if (!ownOnly) fail('invalid-argument');
        const offGeneration = previous.offGeneration + (previous.enabled && !data.accountEnabled ? 1 : 0);
        if (!Number.isSafeInteger(offGeneration)) fail('resource-exhausted');
        tx.set(preferenceRef(uid), {...previous, enabled: data.accountEnabled, revision: previous.revision + 1, offGeneration});
      } else if (!ownOnly) {
        const revision = previous.revision + 1;
        const policy = {...previous, retention: data.retention ?? previous.retention, revision};
        const days = PERIODS[policy.retention], oldDays = PERIODS[previous.retention];
        if (days != null && (oldDays == null || days < oldDays)) {
          policy.shortenings = [...policy.shortenings, {revision, days, at: now()}];
        }
        policy.shortenings = compactShortenings(policy.shortenings);
        tx.set(configRef(state.fid), policy);
      } else fail('invalid-argument');
      return {ok: true, ...(data.initializeIfAbsent === true ? {initialized: true} : {})};
    });
  }
  async function clearHistory(uid, data) {
    exact(data, ['expectedGeneration', 'epoch', 'familyId', 'operationId']); identifier(data.epoch); identifier(data.familyId); identifier(data.operationId);
    if (!Number.isSafeInteger(data.expectedGeneration) || data.expectedGeneration < 0) fail('invalid-argument');
    await rate(uid, 'clearHistory', 10);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid), generation = historyGeneration(state, uid);
      if (data.familyId !== state.fid || data.epoch !== state.members[uid].epoch) fail('failed-precondition');
      const receiptRef = doc(`${root(state.fid)}/chatOperationReceipts/clear_${hash(`${uid}:${data.operationId}`)}`);
      const previous = await read(tx, receiptRef);
      if (previous) {
        if (previous.uid !== uid || previous.epoch !== data.epoch || previous.expectedGeneration !== data.expectedGeneration) fail('already-exists');
        return {generation: previous.generation};
      }
      if (data.expectedGeneration !== generation) fail('already-exists');
      if (!Number.isSafeInteger(generation + 1)) fail('resource-exhausted');
      tx.set(preferenceRef(uid), {...state.preferences[uid], historyFamilyId: state.fid, historyEpoch: state.members[uid].epoch,
        historyGeneration: generation + 1});
      tx.set(receiptRef, {uid, epoch: data.epoch, expectedGeneration: generation, generation: generation + 1,
        deleteAfter: new Date(now() + DAY)});
      return {generation: generation + 1};
    });
  }
  async function reserve(uid, data) {
    exact(data, ['count']);
    const count = data.count ?? 5;
    if (!Number.isInteger(count) || count < 1 || count > 10) fail('invalid-argument');
    await rate(uid, 'tickets', 10);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid);
      return {tickets: Array.from({length: count}, () => {
        const value = {id: randomUUID(), uid, fid: state.fid, epoch: state.members[uid].epoch, version: state.preferences[uid].revision, policyVersion: state.policy.revision, until: now() + DAY};
        const payload = Buffer.from(JSON.stringify(value)).toString('base64url');
        return {id: value.id, expiresAt: value.until, token: `${payload}.${sign(payload)}`};
      })};
    });
  }
  async function send(uid, data) {
    exact(data, ['ticket', 'targetUid', 'kind', 'text', 'answers', 'replyTo', 'treatment', 'verifyOnly', 'answerIndex']);
    if (data.verifyOnly !== undefined && data.verifyOnly !== true) fail('invalid-argument');
    if (!['text', 'question', 'answer', 'lowTreatment'].includes(data.kind) || !textWithin(data.text, 2000)) fail('invalid-argument');
    if (data.kind !== 'lowTreatment' && data.treatment !== undefined) fail('invalid-argument');
    const answers = data.answers ?? [];
    if (!Array.isArray(answers) || answers.length > 6 || answers.some(v => !textWithin(v, 80)) || new Set(answers).size !== answers.length || data.kind !== 'question' && answers.length) fail('invalid-argument');
    if (data.replyTo != null) identifier(data.replyTo);
    const {answerIndex} = data;
    if (answerIndex !== undefined &&
      (data.kind !== 'answer' || data.replyTo == null || !Number.isInteger(answerIndex) || answerIndex < 0 || answerIndex >= 6)) fail('invalid-argument');
    const text = data.text.trim();
    await rate(uid, 'send', 30);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid);
      if (['question', 'lowTreatment'].includes(data.kind) && uid === state.family.childUid) fail('permission-denied');
      if (data.kind === 'lowTreatment' && !['family', state.family.childUid].includes(data.targetUid)) fail('permission-denied');
      const operation = ticket(data.ticket, state, uid);
      if (operation.fid !== state.fid || operation.epoch !== state.members[uid].epoch) unknownOutcome();
      let destination;
      try { destination = target(state, uid, data.targetUid); }
      catch (error) { if (error instanceof FamilyError && error.code === 'permission-denied') unknownOutcome(); throw error; }
      const messageRef = messages(state.fid).doc(operation.id);
      const previous = await read(tx, messageRef);
      const markerRef = doc(`${root(state.fid)}/chatOperationReceipts/${operation.id}`);
      const marker = await read(tx, markerRef);
      const digestFields = [data.targetUid, data.kind, text, answers, data.replyTo ?? null, data.treatment ?? null];
      if (answerIndex !== undefined) digestFields.push(answerIndex);
      const digest = hash(JSON.stringify(digestFields));
      if (marker) {
        if (marker.uid !== uid || marker.digest !== digest) fail('already-exists');
        if (!previous || !visible(previous, state, uid)) unknownOutcome();
        return {message: publicMessage(previous, state.policy, uid)};
      }
      // A stale ticket or a read-only verification must never create a fresh
      // message. Absence is not proof of non-delivery: a send may be in flight.
      if (operation.stale || data.verifyOnly === true) unknownOutcome();
      if (previous) fail('already-exists');
      const treatment = data.kind === 'lowTreatment' ? treatmentSnapshot(data.treatment, now()) : null;
      const recipients = destination.candidates.filter(id => state.preferences[id].enabled);
      if (!recipients.length) fail('failed-precondition');
      if (treatment && !recipients.includes(state.family.childUid)) fail('failed-precondition');
      if (data.replyTo) {
        const parent = await read(tx, messages(state.fid).doc(data.replyTo));
        if (!parent || parent.conversationId !== destination.id || !visible(parent, state, uid)) fail('not-found');
        if (answerIndex !== undefined &&
          (parent.kind !== 'question' || typeof parent.answers?.[answerIndex] !== 'string' || parent.answers[answerIndex].trim() !== text)) fail('invalid-argument');
      }
      const conversationRef = doc(`${root(state.fid)}/chatConversations/${destination.id}`);
      const conversation = await read(tx, conversationRef);
      const time = now(), days = PERIODS[state.policy.retention];
      const participants = Object.fromEntries([uid, ...recipients].map(id => [id, state.members[id].epoch]));
      const message = {id: operation.id, conversationId: destination.id, senderUid: uid, participants,
        sequence: (conversation?.sequence ?? 0) + 1, sentAt: time, expiresAt: days == null ? null : time + days * DAY,
        policyRevision: state.policy.revision, kind: data.kind, text, answers, replyTo: data.replyTo ?? null,
        ...(answerIndex === undefined ? {} : {answerIndex}),
        names: Object.fromEntries([uid, ...recipients].map(id => [id, state.members[id].displayName ?? ''])),
        roles: Object.fromEntries([uid, ...recipients].map(id => [id, state.members[id].role])),
        receipts: Object.fromEntries(recipients.map(id => [id, {deliveredAt: null, readAt: null}]))};
      if (treatment) {
        message.treatment = treatment;
        message.text = treatmentText(treatment);
      }
      storeMessage(tx, state, uid, destination, data.targetUid, recipients, message, !conversation || conversation.unreadIndexVersion === 1);
      tx.set(markerRef, {uid, digest, deleteAfter: new Date(operation.until + DAY)});
      return {message: publicMessage(message, state.policy, uid)};
    });
  }
  function storeMessage(tx, state, uid, destination, targetUid, recipients, message, unreadReady) {
    message.historyGenerations = Object.fromEntries([uid, ...recipients].map(memberUid => [memberUid, historyGeneration(state, memberUid)]));
    tx.set(messages(state.fid).doc(message.id), message);
    tx.set(doc(`${root(state.fid)}/chatConversations/${destination.id}`), {sequence: message.sequence, participants: message.participants,
      targetUids: destination.id === 'family' ? ['family'] : [uid, targetUid], names: message.names,
      unreadIndexVersion: unreadReady ? 1 : 0});
    for (const memberUid of [uid, ...recipients]) {
      const peer = destination.id === 'family' ? 'family' : memberUid === uid ? targetUid : uid;
      tx.set(inbox(state.fid, memberUid, state.members[memberUid].epoch).doc(destination.id), {
        targetUid: peer, displayName: state.members[peer]?.displayName ?? '',
      });
      tx.set(messageIndex(state.fid, memberUid, state.members[memberUid].epoch).doc(message.id), {
        conversationId: destination.id, sequence: message.sequence,
        ownHistoryGeneration: historyGeneration(state, memberUid), policyRevision: message.policyRevision,
        sentAt: message.sentAt, originalExpiresAt: message.expiresAt ?? Number.MAX_SAFE_INTEGER,
        unread: memberUid !== uid,
      });
    }
    for (const recipientUid of recipients) {
      tx.set(doc(`familyChatNotificationJobs/${hash(`${message.id}:${recipientUid}`)}`), {
        familyId: state.fid, messageId: message.id, recipientUid, epoch: state.members[recipientUid].epoch,
        createdAt: message.sentAt, deleteAfter: new Date(message.sentAt + DAY),
      });
    }
  }

  // Internal, server-derived answer: no public endpoint can choose its body,
  // recipient set or ID. Read everything before returning the write closure.
  async function prepareTreatmentResult(tx, uid, claim, parent, time) {
    let state;
    try { state = await scope(tx, uid); }
    catch (error) {
      if (error instanceof FamilyError && ['permission-denied', 'failed-precondition'].includes(error.code)) return null;
      throw error;
    }
    if (state.fid !== claim.familyId || uid !== state.family.childUid || state.members[uid].epoch !== claim.childEpoch ||
        !visible(parent, state, uid) || parent.treatment.validUntil <= time) return null;
    const targetUid = parent.conversationId === 'family' ? 'family' : parent.senderUid;
    let destination;
    try { destination = target(state, uid, targetUid); }
    catch (error) { if (error instanceof FamilyError && error.code === 'permission-denied') return null; throw error; }
    if (destination.id !== parent.conversationId) return null;
    const recipients = destination.candidates.filter(memberUid => state.members[memberUid].role === 'managingCaregiver' &&
      state.preferences[memberUid].enabled && parent.participants[memberUid] === state.members[memberUid].epoch);
    if (!recipients.length) return null;
    const id = hash(`chat-treatment-result:${claim.familyId}:${parent.id}:${uid}`);
    const old = await read(tx, messages(state.fid).doc(id));
    if (old) {
      if (old.kind === 'treatmentResult' && old.senderUid === uid && old.replyTo === parent.id) return null;
      fail('already-exists');
    }
    const conversation = await read(tx, doc(`${root(state.fid)}/chatConversations/${destination.id}`));
    const members = [uid, ...recipients], days = PERIODS[state.policy.retention];
    const message = {id, senderUid: uid, conversationId: destination.id,
      sequence: (conversation?.sequence ?? 0) + 1, sentAt: time,
      expiresAt: days == null ? null : time + days * DAY, policyRevision: state.policy.revision,
      kind: 'treatmentResult', text: `Zjadłem · ${treatmentText(treatmentWithQuantity(parent.treatment, claim.quantity ?? parent.treatment.quantity))}`, answers: [], replyTo: parent.id, resultOf: parent.id,
      participants: Object.fromEntries(members.map(memberUid => [memberUid, state.members[memberUid].epoch])),
      names: Object.fromEntries(members.map(memberUid => [memberUid, state.members[memberUid].displayName ?? ''])),
      roles: Object.fromEntries(members.map(memberUid => [memberUid, state.members[memberUid].role])),
      receipts: Object.fromEntries(recipients.map(memberUid => [memberUid, {deliveredAt: null, readAt: null}]))};
    return () => storeMessage(tx, state, uid, destination, targetUid, recipients, message, !conversation || conversation.unreadIndexVersion === 1);
  }

  async function fetch(uid, data) {
    exact(data, ['targetUid', 'after', 'before', 'latest']);
    const mode = data.latest === true ? 'latest' : data.before !== undefined ? 'before' : 'after';
    if (data.latest !== undefined && data.latest !== true ||
        [data.after !== undefined, data.before !== undefined, data.latest === true].filter(Boolean).length !== 1 ||
        mode !== 'latest' && (!Number.isSafeInteger(data[mode]) || data[mode] < (mode === 'before' ? 1 : 0))) fail('invalid-argument');
    await rate(uid, 'fetch', 120);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid), destination = target(state, uid, data.targetUid, true);
      let query = messageIndex(state.fid, uid, state.members[uid].epoch).where('conversationId', '==', destination.id);
      if (mode !== 'latest') query = query.where('sequence', mode === 'after' ? '>' : '<', data[mode]);
      const rows = await tx.get(query.orderBy('sequence', mode === 'after' ? 'asc' : 'desc').limit(50));
      const indices = rows.docs.map(snap => ({...snap.data(), id: snap.id}));
      const scanned = (await Promise.all(indices.map(row => read(tx, messages(state.fid).doc(row.id))))).filter(Boolean).sort((a, b) => a.sequence - b.sequence);
      return {messages: scanned.filter(message => visible(message, state, uid)).map(message => publicMessage(message, state.policy, uid)),
        cursor: indices.reduce((max, row) => Math.max(max, row.sequence), data.after ?? 0),
        oldestCursor: indices.reduce((min, row) => Math.min(min, row.sequence), data.before ?? Number.MAX_SAFE_INTEGER),
        hasMore: indices.length === 50, serverTime: now(), policy: state.policy};
    });
  }
  async function conversations(uid, data) {
    exact(data, ['after']);
    if (data.after !== undefined && data.after !== '') identifier(data.after);
    await rate(uid, 'conversations', 60);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid);
      let query = inbox(state.fid, uid, state.members[uid].epoch).orderBy('__name__').limit(30);
      if (data.after) query = query.startAfter(data.after);
      const rows = await tx.get(query);
      const time = now();
      const summaries = await Promise.all(rows.docs.map(async snap => {
        const value = snap.data(), targetUid = value.targetUid;
        const conversation = await read(tx, doc(`${root(state.fid)}/chatConversations/${snap.id}`));
        const hasUnread = conversation?.unreadIndexVersion === 1
          ? await hasUnreadMessage(tx, state, uid, snap.id, time) : null;
        return {id: snap.id, targetUid, displayName: value.displayName, active: targetUid === 'family' || !!state.members[targetUid], hasUnread};
      }));
      return {cursor: rows.docs.at(-1)?.id ?? data.after ?? '', hasMore: rows.docs.length === 30,
        familyId: state.fid, epoch: state.members[uid].epoch, historyGeneration: historyGeneration(state, uid),
        serverTime: time, conversations: summaries};
    });
  }
  async function hasUnreadMessage(tx, state, uid, conversationId, time) {
    const frontier = compactShortenings(state.policy.shortenings ?? []);
    let lower = 0;
    for (const change of [...frontier, {revision: null, days: null}]) {
      let query = messageIndex(state.fid, uid, state.members[uid].epoch)
        .where('conversationId', '==', conversationId)
        .where('ownHistoryGeneration', '==', historyGeneration(state, uid))
        .where('unread', '==', true)
        .where('originalExpiresAt', '>', time)
        .where('policyRevision', '>', lower - 1);
      if (change.revision != null) query = query.where('policyRevision', '<', change.revision);
      if (change.days != null) query = query.where('sentAt', '>', time - change.days * DAY);
      if ((await tx.get(query.orderBy('policyRevision').orderBy('originalExpiresAt').orderBy('sentAt').limit(1))).docs.length) return true;
      if (change.revision != null) lower = change.revision;
    }
    return false;
  }
  async function acknowledge(uid, data) {
    exact(data, ['messageId', 'read']); identifier(data.messageId);
    if (typeof data.read !== 'boolean') fail('invalid-argument');
    await rate(uid, 'ack', 120);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid), ref = messages(state.fid).doc(data.messageId);
      const message = await read(tx, ref);
      if (!message || !visible(message, state, uid) || !message.receipts[uid]) fail('not-found');
      const receipt = message.receipts[uid], time = now();
      message.receipts[uid] = {deliveredAt: receipt.deliveredAt ?? time, readAt: receipt.readAt ?? (data.read ? time : null)};
      tx.set(ref, message);
      if (data.read) tx.set(messageIndex(state.fid, uid, state.members[uid].epoch).doc(message.id), {unread: false}, {merge: true});
      return {ok: true};
    });
  }
  // Status refresh is independent of the history cursor: ACKs do not create
  // another message sequence. Never disclose whether another family's ID exists.
  async function states(uid, data) {
    exact(data, ['ids']);
    if (!Array.isArray(data.ids) || data.ids.length > 50 || new Set(data.ids).size !== data.ids.length) fail('invalid-argument');
    data.ids.forEach(identifier);
    await rate(uid, 'states', 60);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid);
      const values = await Promise.all(data.ids.map(id => read(tx, messages(state.fid).doc(id))));
      const found = values.filter(message => message && visible(message, state, uid));
      return {messages: found.map(message => publicMessage(message, state.policy, uid)),
        missing: data.ids.filter(id => !found.some(message => message.id === id)), serverTime: now()};
    });
  }
  async function acknowledgeBatch(uid, data) {
    exact(data, ['items']);
    if (!Array.isArray(data.items) || !data.items.length || data.items.length > 50) fail('invalid-argument');
    for (const item of data.items) {
      exact(item, ['messageId', 'read']); identifier(item.messageId);
      if (typeof item.read !== 'boolean') fail('invalid-argument');
    }
    if (new Set(data.items.map(item => item.messageId)).size !== data.items.length) fail('invalid-argument');
    await rate(uid, 'ackBatch', 60);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid);
      // All reads must precede writes in a real Firestore transaction.
      const values = await Promise.all(data.items.map(item => read(tx, messages(state.fid).doc(item.messageId))));
      const acknowledged = [], ignored = [];
      data.items.forEach((item, index) => {
        const message = values[index];
        if (!message || !visible(message, state, uid) || !message.receipts[uid]) {
          ignored.push(item.messageId); return;
        }
        const receipt = message.receipts[uid];
        if (receipt.deliveredAt == null || item.read && receipt.readAt == null) {
          const time = now();
          message.receipts[uid] = {deliveredAt: receipt.deliveredAt ?? time, readAt: receipt.readAt ?? (item.read ? time : null)};
          tx.set(messages(state.fid).doc(item.messageId), message);
          if (item.read) tx.set(messageIndex(state.fid, uid, state.members[uid].epoch).doc(message.id), {unread: false}, {merge: true});
        }
        acknowledged.push(item.messageId);
      });
      return {acknowledged, ignored, serverTime: now()};
    });
  }
  function shortcutRefs(state, uid) {
    const owner = hash(`${uid}:${state.members[uid].epoch}`);
    return {
      library: doc(`${root(state.fid)}/chatShortcuts/${uid === state.family.childUid ? owner : 'questions'}`),
      order: doc(`${root(state.fid)}/chatShortcutOrders/${owner}`),
    };
  }
  async function shortcuts(uid, data) {
    exact(data, []); await rate(uid, 'shortcuts', 60);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid), refs = shortcutRefs(state, uid);
      const library = await read(tx, refs.library), order = await read(tx, refs.order);
      return {items: library?.items ?? null, revision: library?.revision ?? 0,
        order: order?.ids ?? [], orderRevision: order?.revision ?? 0};
    });
  }
  async function saveShortcuts(uid, data) {
    exact(data, ['items', 'expectedRevision']);
    if (!Number.isSafeInteger(data.expectedRevision) || data.expectedRevision < 0 || !Array.isArray(data.items) || data.items.length > 6) fail('invalid-argument');
    const segmenter = new Intl.Segmenter('und', {granularity: 'grapheme'});
    for (const item of data.items) {
      exact(item, ['id', 'label', 'text', 'emoji', 'answers']); identifier(item.id);
      if (!textWithin(item.label, 40) || !textWithin(item.text, 2000) ||
          typeof item.emoji !== 'string' || !item.emoji.trim() || item.emoji.length > 32 || [...segmenter.segment(item.emoji)].length !== 1 ||
          !Array.isArray(item.answers) || item.answers.length > 6 || item.answers.some(answer => !textWithin(answer, 80)) || new Set(item.answers).size !== item.answers.length) fail('invalid-argument');
    }
    if (new Set(data.items.map(item => item.id)).size !== data.items.length) fail('invalid-argument');
    await rate(uid, 'saveShortcuts', 30);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid), refs = shortcutRefs(state, uid);
      if (uid === state.family.childUid && data.items.some(item => item.answers.length)) fail('invalid-argument');
      const previous = await read(tx, refs.library);
      if ((previous?.revision ?? 0) !== data.expectedRevision) fail('already-exists');
      tx.set(refs.library, {items: data.items, revision: data.expectedRevision + 1});
      return {ok: true};
    });
  }
  async function orderShortcuts(uid, data) {
    exact(data, ['ids', 'expectedRevision']);
    if (!Number.isSafeInteger(data.expectedRevision) || data.expectedRevision < 0 || !Array.isArray(data.ids) || data.ids.length > 6 || new Set(data.ids).size !== data.ids.length) fail('invalid-argument');
    data.ids.forEach(identifier); await rate(uid, 'orderShortcuts', 30);
    return store.runTransaction(async tx => {
      const state = await scope(tx, uid), refs = shortcutRefs(state, uid);
      const library = await read(tx, refs.library), previous = await read(tx, refs.order);
      if ((previous?.revision ?? 0) !== data.expectedRevision) fail('already-exists');
      if (data.ids.some(id => !library?.items.some(item => item.id === id))) fail('invalid-argument');
      tx.set(refs.order, {ids: data.ids, revision: data.expectedRevision + 1});
      return {ok: true};
    });
  }
  return {getConfig, configure, clearHistory, reserve, send, fetch, conversations, acknowledge, states, acknowledgeBatch, shortcuts, saveShortcuts, orderShortcuts, scope, expiresAt, visible, publicMessage, prepareTreatmentResult, rate};
}
module.exports = {createChatService, PERIODS, DAY};
