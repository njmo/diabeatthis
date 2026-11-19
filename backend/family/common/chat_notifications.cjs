'use strict';
const {randomUUID} = require('node:crypto');
const {FamilyError, exact, hash, matches} = require('./security.cjs');
const DAY = 86400000;
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);

function createChatNotifications({store, chat, messaging, now = Date.now}) {
  const devices = store.collection('familyChatDevices');
  async function register(uid, data) {
    exact(data, ['token', 'enabled', 'installationId', 'counter', 'revocationToken']);
    if (typeof data.enabled !== 'boolean' || typeof data.token !== 'string' || data.token.length < 20 || data.token.length > 4096) throw new FamilyError('invalid-argument');
    const ref = devices.doc(hash(data.token));
    const tracked = data.installationId !== undefined || data.counter !== undefined;
    if (tracked && (typeof data.installationId !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(data.installationId) || typeof data.revocationToken !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(data.revocationToken) || !Number.isSafeInteger(data.counter) || data.counter < 1)) throw new FamilyError('invalid-argument');
    await store.runTransaction(async tx => {
      const previous = (await tx.get(ref)).data();
      const installation = tracked ? store.doc(`familyChatInstallations/${hash(data.installationId)}`) : null;
      const old = installation ? (await tx.get(installation)).data() : null;
      if (previous?.installationId && !tracked) throw new FamilyError('failed-precondition');
      if (tracked && old && old.counter >= data.counter) {
        if (old.counter === data.counter && old.uid === uid && old.tokenId === ref.id && old.enabled === data.enabled) return;
        throw new FamilyError('already-exists');
      }
      if (tracked && previous?.installationId === data.installationId && previous.counter >= data.counter) throw new FamilyError('already-exists');
      const saveCounter = () => { if (installation) tx.set(installation, {counter: data.counter, uid, tokenId: ref.id, enabled: data.enabled, updatedAt: now(), deleteAfter: new Date(now() + 30 * DAY)}); };
      if (!data.enabled) {
        if (previous?.uid === uid) tx.delete(ref);
        saveCounter();
        return;
      }
      const state = await chat.scope(tx, uid);
      const registered = await tx.get(devices.where('uid', '==', uid));
      const rateRef = store.doc(`familyRateLimits/${hash(`chat:devices:${uid}`)}`);
      const oldRate = (await tx.get(rateRef)).data(), time = now();
      const current = oldRate && oldRate.start + 60000 > time;
      const count = current ? oldRate.count + 1 : 1;
      if (count > 30) throw new FamilyError('resource-exhausted');
      const ordered = registered.docs.filter(row => row.id !== ref.id).sort((a, b) => a.data().updatedAt - b.data().updatedAt);
      while (ordered.length >= 10) tx.delete(devices.doc(ordered.shift().id));
      tx.set(ref, {uid, familyId: state.fid, epoch: state.members[uid].epoch, token: data.token, updatedAt: time, generation: randomUUID(), ...(tracked ? {installationId: data.installationId, counter: data.counter, revocationDigest: hash(data.revocationToken)} : {})});
      saveCounter();
      tx.set(rateRef, {start: current ? oldRate.start : time, count, deleteAfter: new Date(time + DAY)});
    });
    return {ok: true};
  }

  // This capability can only remove its exact registration, never send a push
  // or inspect content. It remains usable after Firebase Auth signs out.
  async function revoke(data) {
    exact(data, ['token', 'installationId', 'counter', 'revocationToken']);
    if (typeof data.token !== 'string' || data.token.length < 20 || data.token.length > 4096 || !/^[A-Za-z0-9_-]{43}$/.test(data.installationId ?? '') || !/^[A-Za-z0-9_-]{43}$/.test(data.revocationToken ?? '') || !Number.isSafeInteger(data.counter) || data.counter < 1) throw new FamilyError('invalid-argument');
    return store.runTransaction(async tx => {
      const ref = devices.doc(hash(data.token));
      const binding = (await tx.get(ref)).data();
      const installation = (await tx.get(store.doc(`familyChatInstallations/${hash(data.installationId)}`))).data();
      if (binding?.installationId === data.installationId && binding.counter === data.counter) {
        if (!matches(data.revocationToken, binding.revocationDigest)) throw new FamilyError('permission-denied');
        tx.delete(ref);
        return {ok: true};
      }
      // A later installation counter makes this attempt permanently obsolete.
      return installation?.counter >= data.counter ? {ok: true} : {pending: true};
    });
  }

  async function dispatch(jobId) {
    if (!validId(jobId)) return;
    const ref = store.doc(`familyChatNotificationJobs/${jobId}`), leaseId = randomUUID();
    const delivery = await store.runTransaction(async tx => {
      const job = (await tx.get(ref)).data();
      if (!job || ['sent', 'cancelled'].includes(job.status)) return null;
      if (job.status === 'sending' && job.leaseUntil > now()) throw new Error('Chat dispatch in progress');
      if (![job.familyId, job.messageId, job.recipientUid].every(validId) || jobId !== hash(`${job.messageId}:${job.recipientUid}`)) return null;
      const cancel = () => { tx.set(ref, {...job, status: 'cancelled', deleteAfter: new Date(now() + DAY)}); return null; };
      let state;
      try { state = await chat.scope(tx, job.recipientUid); }
      catch (error) { if (error instanceof FamilyError && ['permission-denied', 'failed-precondition'].includes(error.code)) return cancel(); throw error; }
      if (state.fid !== job.familyId || state.members[job.recipientUid].epoch !== job.epoch) return cancel();
      const message = (await tx.get(store.doc(`families/${job.familyId}/chatMessages/${job.messageId}`))).data();
      if (!message ||
          !chat.visible(message, state, job.recipientUid) || !message.receipts[job.recipientUid] ||
          !state.members[message.senderUid] || state.members[message.senderUid].epoch !== message.participants[message.senderUid] || !state.preferences[message.senderUid].enabled) return cancel();
      const registered = await tx.get(devices.where('uid', '==', job.recipientUid));
      const eligible = registered.docs.map(row => ({id: row.id, ...row.data()})).filter(device => device.familyId === state.fid && device.epoch === job.epoch);
      const completed = (job.completed ?? []).filter(mark => eligible.some(device => device.id === mark.id && device.generation === mark.generation));
      const tokens = eligible.filter(device => !completed.some(mark => mark.id === device.id && mark.generation === device.generation));
      const validUntil = message.kind === 'lowTreatment' ? message.treatment.validUntil : now() + DAY;
      const ttl = Math.min(DAY, validUntil - now(), (chat.expiresAt(message, state.policy) ?? now() + DAY) - now());
      if (ttl <= 0 || !eligible.length) return cancel();
      if (!tokens.length) { tx.set(ref, {...job, completed, status: 'sent', sentAt: now(), deleteAfter: new Date(now() + DAY)}); return null; }
      tx.set(ref, {...job, completed, status: 'sending', leaseId, leaseUntil: now() + 120000});
      return {tokens, ttl, data: {type: 'familyChat', uid: job.recipientUid, familyId: job.familyId, epoch: job.epoch, messageId: job.messageId}};
    });
    if (!delivery) return;
    try {
      // No message text or suggested answers are ever sent through FCM.
      const result = await messaging.sendEachForMulticast({tokens: delivery.tokens.map(device => device.token), data: delivery.data, android: {priority: 'high', ttl: delivery.ttl}});
      let retry = result.responses.length !== delivery.tokens.length;
      const completed = [];
      const invalid = [];
      for (const [index, response] of result.responses.entries()) {
        const device = delivery.tokens[index];
        if (!device) { retry = true; continue; }
        if (response.success) { completed.push({id: device.id, generation: device.generation}); continue; }
        if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(response.error?.code)) {
          invalid.push(device);
        } else retry = true;
      }
      // Keep known acceptances even if subsequent device cleanup fails.
      await store.runTransaction(async tx => {
        const current = (await tx.get(ref)).data();
        if (current?.leaseId === leaseId) tx.set(ref, {...current, completed: [...(current.completed ?? []), ...completed]});
      });
      for (const device of invalid) {
          const rebound = await store.runTransaction(async tx => {
            const current = (await tx.get(devices.doc(device.id))).data();
            if (current?.generation === device.generation) tx.delete(devices.doc(device.id));
            return current && current.generation !== device.generation;
          });
          if (rebound) retry = true;
      }
      await store.runTransaction(async tx => {
        const current = (await tx.get(ref)).data();
        if (current?.leaseId === leaseId) tx.set(ref, {...current, status: retry ? 'pending' : 'sent', leaseUntil: 0, sentAt: retry ? null : now(), deleteAfter: new Date(now() + DAY)});
      });
      if (retry) throw new Error('Chat notification temporarily unavailable');
    } catch (error) {
      await store.runTransaction(async tx => {
        const current = (await tx.get(ref)).data();
        if (current?.leaseId === leaseId) tx.set(ref, {...current, status: 'pending', leaseUntil: 0});
      });
      throw error;
    }
  }
  return {register, revoke, dispatch};
}
module.exports = {createChatNotifications};
