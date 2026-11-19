'use strict';
const {hash} = require('./security.cjs');
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const checkpointPath = 'familyChatMaintenance/messages';

// Scheduled backend-only work. Callables already hide expired content; this
// bounded circular scan removes it physically, including orphan subcollections.
function createChatCleanup({store, chat, now = Date.now, pageSize = 100, maxMillis = 25000}) {
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 200) throw new Error('Invalid cleanup budget');
  const checkpoint = store.doc(checkpointPath);
  async function step(path, expectedCursor) {
    return store.runTransaction(async tx => {
      const progress = (await tx.get(checkpoint)).data() ?? {};
      if ((progress.cursor ?? '') !== expectedCursor) return {stale: true};
      const parts = path.split('/');
      const validPath = parts.length === 4 && parts[0] === 'families' && parts[2] === 'chatMessages' && validId(parts[1]) && validId(parts[3]);
      const advance = extra => tx.set(checkpoint, {...progress, cursor: path, updatedAt: now(), ...extra});
      if (!validPath) { advance({lastErrorPath: path, lastError: 'invalid-path'}); return {invalid: true}; }
      const fid = parts[1], messageId = parts[3];
      const ref = store.doc(path);
      const message = (await tx.get(ref)).data();
      if (!message) { advance({}); return {skipped: true}; }
      const family = (await tx.get(store.doc(`families/${fid}`))).data();
      const policy = (await tx.get(store.doc(`families/${fid}/chatConfig/current`))).data();
      // Missing config on an existing family means the documented default week.
      // Only canonical server messages with valid expiry metadata are eligible.
      const validMessage = Number.isSafeInteger(message.sentAt) &&
        Number.isSafeInteger(message.policyRevision) && message.policyRevision >= 0 &&
        (message.expiresAt === null || Number.isSafeInteger(message.expiresAt)) &&
        message.participants && typeof message.participants === 'object' && !Array.isArray(message.participants) &&
        Object.keys(message.participants).length <= 6 && Object.entries(message.participants).every(([uid, epoch]) => validId(uid) && validId(epoch));
      const validPolicy = policy == null || Array.isArray(policy.shortenings) && policy.shortenings.every(change =>
        Number.isSafeInteger(change.revision) && change.revision > 0 && [1, 7, 30].includes(change.days));
      if (!validMessage || family && !validPolicy) {
        advance({lastErrorPath: path, lastError: 'invalid-metadata'}); return {invalid: true};
      }
      const expiry = family ? chat.expiresAt(message, policy ?? {shortenings: []}) : 0;
      if (expiry == null || expiry > now()) { advance({}); return {skipped: true}; }
      const jobs = [];
      for (const uid of Object.keys(message.participants)) {
        const jobRef = store.doc(`familyChatNotificationJobs/${hash(`${messageId}:${uid}`)}`);
        const job = (await tx.get(jobRef)).data();
        if (job?.familyId === fid && job.messageId === messageId && job.recipientUid === uid) jobs.push(jobRef);
      }
      // All reads precede writes. OFF/retention updates and message completion
      // conflict with this transaction, so eligibility is re-evaluated on retry.
      tx.delete(ref);
      for (const [uid, epoch] of Object.entries(message.participants)) {
        tx.delete(store.doc(`families/${fid}/chatInboxes/${hash(`${uid}:${epoch}`)}/chatMessageIndex/${messageId}`));
      }
      for (const job of jobs) tx.delete(job);
      // Operation receipts and clinical claims deliberately outlive the body.
      advance({});
      return {deleted: true};
    });
  }
  async function run() {
    const start = performance.now();
    let cursor = await store.runTransaction(async tx => (await tx.get(checkpoint)).data()?.cursor ?? '');
    let query = store.collectionGroup('chatMessages').orderBy('__name__').limit(pageSize);
    if (cursor) query = query.startAfter(store.doc(cursor));
    const page = await store.runTransaction(tx => tx.get(query));
    const result = {scanned: 0, deleted: 0, skipped: 0, invalid: 0, stale: false, completed: false};
    for (const snapshot of page.docs) {
      if (performance.now() - start >= maxMillis) return result;
      const next = snapshot.ref.path;
      const outcome = await step(next, cursor);
      if (outcome.stale) return {...result, stale: true};
      result.scanned++;
      for (const key of ['deleted', 'skipped', 'invalid']) if (outcome[key]) result[key]++;
      cursor = next;
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
  return {run};
}

module.exports = {createChatCleanup};
