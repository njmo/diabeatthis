'use strict';
const {FamilyError, hash} = require('./security.cjs');
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);

function createChatOrphanCleanup({store, chat, now = Date.now, pageSize = 25, maxMillisPerPass = 5000}) {
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) throw new Error('Invalid cleanup budget');
  async function familyState(tx, fid) {
    const family = (await tx.get(store.doc(`families/${fid}`))).data();
    if (!family) return null;
    if (!validId(family.childUid)) throw new FamilyError('failed-precondition');
    const state = await chat.scope(tx, family.childUid, false);
    if (state.fid !== fid) throw new FamilyError('failed-precondition');
    if (!Array.isArray(state.policy.shortenings) || state.policy.shortenings.some(change =>
      !Number.isSafeInteger(change.revision) || change.revision < 1 || ![1, 7, 30].includes(change.days))) {
      throw new FamilyError('failed-precondition');
    }
    return state;
  }
  async function clean(tx, kind, ref, value) {
    const path = ref.path.split('/');
    if (kind === 'devices') {
      if (path.length !== 2 || path[0] !== 'familyChatDevices') return 'foreign';
      let keep = false;
      if (validId(value.uid)) {
        try {
          const state = await chat.scope(tx, value.uid);
          keep = state.fid === value.familyId && state.members[value.uid].epoch === value.epoch;
        } catch (error) { if (!(error instanceof FamilyError)) throw error; }
      }
      if (!keep) { tx.delete(ref); return 'deleted'; }
      return 'kept';
    }
    const nested = kind === 'indices' || kind === 'threads';
    const collection = kind === 'indices' ? 'chatMessageIndex' : kind === 'threads' ? 'threads' : 'chatConversations';
    if (path.length !== (nested ? 6 : 4) || path[0] !== 'families' ||
        path[nested ? 4 : 2] !== collection || nested && path[2] !== 'chatInboxes') return 'foreign';
    if (![path[1], path.at(-1), ...(nested ? [path[3]] : [])].every(validId)) return 'invalid';
    const fid = path[1];
    if (kind === 'conversations') {
      if (!Number.isSafeInteger(value.sequence) || value.sequence < 0) return 'invalid';
      const rows = await tx.get(store.collection(`families/${fid}/chatMessages`).where('conversationId', '==', ref.id).limit(1));
      if (rows.docs.length) return 'kept';
      if (Object.keys(value).length === 1 && Object.hasOwn(value, 'sequence')) return 'kept';
      // The counter remains: a concurrent send reads/writes this same document
      // and conflicts with cleanup before either can commit stale metadata.
      tx.set(ref, {sequence: value.sequence});
      return 'redacted';
    }
    const state = await familyState(tx, fid);
    const owner = state && Object.keys(state.members).find(uid => hash(`${uid}:${state.members[uid].epoch}`) === path[3]);
    if (!owner) { tx.delete(ref); return 'deleted'; }
    if (kind === 'threads') {
      const indices = await tx.get(store.collection(`families/${fid}/chatInboxes/${path[3]}/chatMessageIndex`)
        .where('conversationId', '==', ref.id).limit(1));
      if (indices.docs.length) return 'kept';
      tx.delete(ref); return 'deleted';
    }
    const message = (await tx.get(store.doc(`families/${fid}/chatMessages/${ref.id}`))).data();
    if (!message) { tx.delete(ref); return 'deleted'; }
    if (!Number.isSafeInteger(message.sentAt) || !Number.isSafeInteger(message.policyRevision) ||
        !(message.expiresAt === null || Number.isSafeInteger(message.expiresAt))) return 'invalid';
    if (!chat.visible(message, state, owner)) { tx.delete(ref); return 'deleted'; }
    return 'kept';
  }
  async function pass(kind, query) {
    const checkpoint = store.doc(`familyChatMaintenance/${kind}`);
    let cursor = await store.runTransaction(async tx => (await tx.get(checkpoint)).data()?.cursor ?? '');
    query = query.orderBy('__name__').limit(pageSize);
    if (cursor) query = query.startAfter(store.doc(cursor));
    const page = await store.runTransaction(tx => tx.get(query));
    const result = {scanned: 0, deleted: 0, redacted: 0, invalid: 0, completed: false, stale: false};
    const started = performance.now();
    for (const snapshot of page.docs) {
      if (performance.now() - started >= maxMillisPerPass) return result;
      const outcome = await store.runTransaction(async tx => {
        const progress = (await tx.get(checkpoint)).data() ?? {};
        if ((progress.cursor ?? '') !== cursor) return 'stale';
        const ref = store.doc(snapshot.ref.path);
        const value = (await tx.get(ref)).data();
        let action = 'kept';
        try { if (value) action = await clean(tx, kind, ref, value); }
        catch (error) {
          if (!(error instanceof FamilyError)) throw error;
          action = 'invalid';
        }
        tx.set(checkpoint, {...progress, cursor: ref.path, updatedAt: now(),
          ...(action === 'invalid' ? {lastErrorPath: ref.path, lastError: 'invalid-metadata'} : {})});
        return action;
      });
      if (outcome === 'stale') return {...result, stale: true};
      result.scanned++;
      if (['deleted', 'redacted', 'invalid'].includes(outcome)) result[outcome]++;
      cursor = snapshot.ref.path;
    }
    if (page.docs.length < pageSize) {
      result.completed = await store.runTransaction(async tx => {
        const progress = (await tx.get(checkpoint)).data() ?? {};
        if ((progress.cursor ?? '') !== cursor) return false;
        tx.set(checkpoint, {...progress, cursor: '', updatedAt: now(), completedAt: now()});
        return true;
      });
    }
    return result;
  }
  async function run() {
    return {
      indices: await pass('indices', store.collectionGroup('chatMessageIndex')),
      threads: await pass('threads', store.collectionGroup('threads')),
      conversations: await pass('conversations', store.collectionGroup('chatConversations')),
      devices: await pass('devices', store.collection('familyChatDevices')),
    };
  }
  return {run};
}
module.exports = {createChatOrphanCleanup};
