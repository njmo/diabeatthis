'use strict';
const {FamilyError, exact, hash, matches} = require('./security.cjs');
const WINDOW = 30 * 60000;
const nutritionCarbs = value => Math.floor(value * 1000000 + .5) / 1000000;
const fail = code => { throw new FamilyError(code); };
const identifier = value => {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) fail('invalid-argument');
  return value;
};

// Freeze the conversion used by the sender, never infer a piece from its name.
function treatmentSnapshot(value, time) {
  exact(value, ['foodName', 'quantity', 'unit', 'gramsPerUnit', 'carbsPer100g', 'carbsPerUnit', 'validUntil']);
  const positive = v => typeof v === 'number' && Number.isFinite(v) && v > 0;
  const reference = value.unit === 'portion';
  if (typeof value.foodName !== 'string' || !value.foodName.trim() || value.foodName.length > 160 ||
      !['piece', 'g', 'ml', 'portion'].includes(value.unit) || !positive(value.quantity) || value.quantity > 10000 ||
      (reference ? value.gramsPerUnit != null || value.carbsPer100g != null || !positive(value.carbsPerUnit) || value.carbsPerUnit > 100
        : !positive(value.gramsPerUnit) || !positive(value.carbsPer100g) || value.carbsPer100g > 100 ||
          value.carbsPerUnit != null && (!positive(value.carbsPerUnit) || Math.abs(value.carbsPerUnit - value.gramsPerUnit * value.carbsPer100g / 100) > 1e-9 * Math.max(1, value.carbsPerUnit))) ||
      value.unit === 'g' && value.gramsPerUnit !== 1 ||
      !Number.isSafeInteger(value.validUntil) || value.validUntil <= time || value.validUntil > time + WINDOW) fail('invalid-argument');
  const grams = reference ? null : value.quantity * value.gramsPerUnit;
  const perUnit = value.carbsPerUnit ?? value.gramsPerUnit * value.carbsPer100g / 100;
  const carbs = nutritionCarbs(value.quantity * perUnit);
  // Keep milligram precision rather than accepting values that
  // underflow or appear as zero in the child's confirmation.
  if (!reference && (!Number.isFinite(grams) || grams < 0.001 || grams > 10000) || !Number.isFinite(carbs) || carbs < .5 || carbs > 10000) fail('invalid-argument');
  return {...value, foodName: value.foodName.trim(), grams, carbs, carbsPerUnit: perUnit, deliveryCarbs: Math.floor(carbs + .5)};
}
function treatmentText(value) {
  const number = v => v.toLocaleString('en-US', {useGrouping: false, maximumSignificantDigits: 10});
  const amount = ['piece', 'portion'].includes(value.unit) ? `${number(value.quantity)} ×` : `${number(value.quantity)} ${value.unit}`;
  return `${amount} ${value.foodName} · ${number(value.carbs)} g WW${value.deliveryCarbs === value.carbs ? '' : ` · zapis ${value.deliveryCarbs} g`}`;
}

// The child may report a different quantity, but never a different conversion.
function treatmentWithQuantity(source, quantity) {
  return treatmentSnapshot({foodName: source.foodName, unit: source.unit, quantity,
    gramsPerUnit: source.gramsPerUnit ?? null, carbsPer100g: source.carbsPer100g ?? null,
    carbsPerUnit: source.carbsPerUnit, validUntil: source.validUntil}, source.validUntil - 1);
}

function createChatTreatment({store, chat, now = Date.now}) {
  async function claim(uid, data) {
    exact(data, ['messageId', 'installationId', 'proof', 'quantity', 'authorization']);
    exact(data.authorization, ['epoch', 'accountOffGeneration', 'familyOffGeneration']);
    identifier(data.authorization.epoch);
    if (!['accountOffGeneration', 'familyOffGeneration'].every(key => Number.isSafeInteger(data.authorization[key]) && data.authorization[key] >= 0)) fail('invalid-argument');
    identifier(data.messageId); identifier(data.installationId);
    if (typeof data.proof !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(data.proof)) fail('invalid-argument');
    await chat.rate(uid, 'treatmentClaim', 30);
    return store.runTransaction(async tx => {
      const state = await chat.scope(tx, uid);
      if (uid !== state.family.childUid) fail('permission-denied');
      const authorization = {epoch: state.members[uid].epoch,
        accountOffGeneration: state.preferences[uid].offGeneration,
        familyOffGeneration: state.policy.offGeneration};
      const sameAuthorization = value => value && Object.keys(authorization).every(key => value[key] === authorization[key]);
      if (!sameAuthorization(data.authorization)) fail('failed-precondition');
      const message = (await tx.get(store.doc(`families/${state.fid}/chatMessages/${data.messageId}`))).data();
      const unavailable = () => { throw new FamilyError('not-found', undefined, {reason: 'consumption-request-unavailable'}); };
      if (!message || message.kind !== 'lowTreatment' || message.participants?.[uid] !== state.members[uid].epoch ||
          !message.receipts?.[uid] || !Number.isSafeInteger(message.treatment?.validUntil)) unavailable();
      const expiry = chat.expiresAt(message, state.policy);
      if (message.treatment.validUntil <= now() || expiry != null && expiry <= now()) {
        throw new FamilyError('not-found', undefined, {reason: 'consumption-request-expired'});
      }
      if (!chat.visible(message, state, uid) || message.participants[message.senderUid] !== state.members[message.senderUid]?.epoch) unavailable();
      // Sender OFF can be temporary; it must not permanently cancel consent.
      if (!state.preferences[message.senderUid]?.enabled) fail('not-found');
      const claimId = hash(`${state.fid}:${message.id}:${uid}`);
      const ref = store.doc(`familyChatTreatmentClaims/${claimId}`);
      const previous = (await tx.get(ref)).data();
      if (previous && (previous.uid !== uid || previous.installationId !== data.installationId)) fail('already-exists');
      if (previous && !matches(data.proof, previous.proofDigest)) fail('already-exists');
      // Missing historical generations cannot prove consent survived OFF→ON.
      if (previous && !sameAuthorization(previous.authorization)) fail('failed-precondition');
      const actual = treatmentWithQuantity(message.treatment,
        Object.hasOwn(data, 'quantity') ? data.quantity : message.treatment.quantity);
      if (previous && (previous.quantity ?? message.treatment.quantity) !== actual.quantity) fail('failed-precondition');
      if (previous?.completedAt != null) return {claimId, completed: true};
      // Never transfer an ambiguous claim to another installation. A restarted
      // owner consults its clinical journal before requesting another lease.
      const time = now();
      const executionUntil = Math.min(time + 60000, message.treatment.validUntil, chat.expiresAt(message, state.policy) ?? Infinity);
      tx.set(ref, {uid, familyId: state.fid, messageId: message.id,
        installationId: data.installationId, proofDigest: hash(data.proof), executionUntil,
        quantity: actual.quantity,
        authorization,
        childEpoch: state.members[uid].epoch, createdAt: previous?.createdAt ?? time, completedAt: null});
      return {claimId, executionUntil, serverTime: time, treatment: actual};
    });
  }
  async function complete(uid, data) {
    exact(data, ['claimId', 'proof']); identifier(data.claimId);
    await chat.rate(uid, 'treatmentComplete', 60);
    return store.runTransaction(async tx => {
      const ref = store.doc(`familyChatTreatmentClaims/${data.claimId}`);
      const value = (await tx.get(ref)).data();
      // Minimal finalization remains possible after OFF, expiry or unlink.
      // It cannot return message contents, renew a lease or create a local effect.
      if (!value || value.uid !== uid || !matches(data.proof, value.proofDigest)) fail('permission-denied');
      if (value.completedAt == null) {
        const messageRef = store.doc(`families/${value.familyId}/chatMessages/${value.messageId}`);
        const message = (await tx.get(messageRef)).data();
        const completedAt = now();
        const publish = message?.kind === 'lowTreatment' && message.participants?.[uid] === value.childEpoch
          ? await chat.prepareTreatmentResult(tx, uid, value, message, completedAt) : null;
        tx.set(ref, {...value, completedAt});
        if (message?.kind === 'lowTreatment' && message.participants?.[uid] === value.childEpoch) {
          tx.set(messageRef, {...message, treatmentResult: {uid, completedAt, quantity: value.quantity ?? message.treatment.quantity}});
        }
        publish?.();
      }
      return {ok: true};
    });
  }
  return {claim, complete};
}
module.exports = {treatmentSnapshot, treatmentText, treatmentWithQuantity, createChatTreatment, WINDOW};
