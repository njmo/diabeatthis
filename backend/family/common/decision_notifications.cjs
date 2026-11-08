'use strict';
const {createHash, randomUUID} = require('node:crypto');
const DISPATCH_LEASE_MS = 120000;
const {FamilyError} = require('./security.cjs');
const MAX_DEVICES = 10;
const tokenId = token => createHash('sha256').update(token).digest('hex');
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);

function createDecisionNotifications({store, messaging, now = Date.now}) {
  async function register(uid, data) {
    if (!data || Object.keys(data).sort().join(',') !== 'enabled,token' || typeof data.enabled !== 'boolean' || typeof data.token !== 'string' || data.token.length < 20 || data.token.length > 4096) throw new FamilyError('invalid-argument');
    const accountRef = store.doc(`familyAccounts/${uid}`);
    const tokens = store.collection(`familyMealDecisionPreferences/${uid}/devices`);
    const id = tokenId(data.token);
    await store.runTransaction(async tx => {
      const binding = store.doc(`familyMealDecisionDeviceBindings/${id}`);
      const old = (await tx.get(binding)).data();
      if (!data.enabled) {
        tx.delete(tokens.doc(id));
        if (old?.uid === uid) tx.delete(binding);
        return;
      }
      const account = (await tx.get(accountRef)).data();
      if (!account?.familyId || !['child', 'managingCaregiver'].includes(account.role)) throw new FamilyError('permission-denied');
      const family = (await tx.get(store.doc(`families/${account.familyId}`))).data();
      const member = (await tx.get(store.doc(`families/${account.familyId}/members/${uid}`))).data();
      if (member?.role !== account.role || !family?.memberUids?.includes(uid) || (account.role === 'child' ? family.childUid !== uid : !family.managerUids?.includes(uid))) throw new FamilyError('permission-denied');
      const existing = await tx.get(tokens);
      if (old?.uid && old.uid !== uid) tx.delete(store.doc(`familyMealDecisionPreferences/${old.uid}/devices/${id}`));
      const ordered = existing.docs.filter(doc => doc.id !== id).sort((a,b) => (a.data().updatedAt || 0) - (b.data().updatedAt || 0));
      while (ordered.length >= MAX_DEVICES) tx.delete(tokens.doc(ordered.shift().id));
      tx.set(tokens.doc(id), {token: data.token, updatedAt: now()});
      tx.set(binding, {uid});
    });
    return {ok: true};
  }
  async function dispatch(jobId, job) {
    const {childUid, recipientUid, requestId} = job || {};
    if (![jobId, childUid, recipientUid, requestId].every(validId)) return;
    const marker = store.doc(`familyMealDecisionDispatches/${jobId}`);
    const leaseId = randomUUID();
    const result = await store.runTransaction(async tx => {
      const previous = (await tx.get(marker)).data();
      if (previous?.status === 'sent') return null;
      if (previous?.status === 'sending' && previous.leaseUntil > now()) throw new Error('Notification delivery is already in progress');
      const decision = (await tx.get(store.doc(`userMirrors/${childUid}/mealDecisions/${requestId}`))).data();
      const childResponse = job.kind === 'response' && childUid === recipientUid;
      if (!decision || decision.status !== (childResponse ? 'responded' : 'open') || decision.deadline <= now() || !validId(decision.familyId) || (!childResponse && (decision.declinedUids || []).includes(recipientUid))) return null;
      if (childResponse && (await tx.get(store.doc(`userMirrors/${childUid}`))).data()?.sourceId !== decision.sourceId) return null;
      const family = (await tx.get(store.doc(`families/${decision.familyId}`))).data();
      const account = (await tx.get(store.doc(`familyAccounts/${recipientUid}`))).data();
      const member = (await tx.get(store.doc(`families/${decision.familyId}/members/${recipientUid}`))).data();
      const pref = (await tx.get(store.doc(`familyMealDecisionPreferences/${recipientUid}`))).data();
      const devices = await tx.get(store.collection(`familyMealDecisionPreferences/${recipientUid}/devices`));
      if (family?.childUid !== childUid || !family.memberUids?.includes(recipientUid) || account?.familyId !== decision.familyId || (!childResponse && pref?.enabled !== true)) return null;
      if (childResponse ? account.role !== 'child' || member?.role !== 'child' : !family.managerUids?.includes(recipientUid) || account.role !== 'managingCaregiver' || member?.role !== 'managingCaregiver') return null;
      tx.set(marker, {status: 'sending', leaseId, leaseUntil: now() + DISPATCH_LEASE_MS});
      return {tokens: devices.docs.map(doc => ({id: doc.id, token: doc.data().token})).filter(device => typeof device.token === 'string'), ttl: Math.max(0, decision.deadline - now())};
    });
    if (!result) return;
    try {
      const sent = result.tokens.length && result.ttl > 0 ? await messaging.sendEachForMulticast({tokens: result.tokens.map(device => device.token), data: {requestId}, android: {priority: 'high', ttl: result.ttl}}) : null;
      /* Process individual errors; successful recipients are deduplicated by notification ID. */
     
      let transient = false;
      for (const [index, response] of (sent?.responses || []).entries()) {
        if (response.success) continue;
        if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(response.error?.code)) {
          await store.doc(`familyMealDecisionPreferences/${recipientUid}/devices/${result.tokens[index].id}`).delete();
        } else {
          transient = true;
        }
      }
      if (transient) throw new Error('Notification delivery temporarily unavailable');
      await store.runTransaction(async tx => {
        const current = (await tx.get(marker)).data();
        if (current?.leaseId === leaseId && current.status === 'sending') tx.set(marker, {status: 'sent', sentAt: now()});
      });
    } catch (error) {
      await store.runTransaction(async tx => {
        const current = (await tx.get(marker)).data();
        if (current?.leaseId === leaseId && current.status === 'sending') tx.delete(marker);
      });
      throw error;
    }
  }
  return {register, dispatch};
}
module.exports = {createDecisionNotifications};
