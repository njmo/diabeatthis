'use strict';
const { createHash, createHmac, randomBytes, timingSafeEqual } = require('node:crypto');
class FamilyError extends Error {
  constructor(code, message = 'Family operation is not permitted') { super(message); this.code = code; }
}
function requireGoogle(request) {
  const auth = request.auth;
  if (!auth || typeof auth.uid !== 'string' || !auth.uid || auth.uid.includes('/') || auth.uid.length > 128 || auth.token?.firebase?.sign_in_provider !== 'google.com' || auth.token.email_verified !== true) {
    throw new FamilyError('unauthenticated');
  }
  if (!request.app || request.app.alreadyConsumed) throw new FamilyError('failed-precondition');
  return auth.uid;
}
function id(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{20,128}$/.test(value)) throw new FamilyError('invalid-argument');
  return value;
}
function exact(data, keys) {
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).some(key => !keys.includes(key))) throw new FamilyError('invalid-argument');
  return data;
}
const CROCKFORD_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
function randomCrockford8() {
  // 256 is divisible by 32, so masking introduces no modulo bias.
  return Array.from(randomBytes(8), byte => CROCKFORD_ALPHABET[byte & 31]).join('');
}
function normalizeCrockford(code) {
  if (typeof code !== 'string' || code.length < 8 || code.length > 32) throw new FamilyError('invalid-argument');
  const normalized = code.replace(/[-\s]/g, '').toUpperCase().replace(/[IL]/g, '1').replace(/O/g, '0');
  if (!/^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$/.test(normalized)) throw new FamilyError('invalid-argument');
  return normalized;
}
function formatCrockford8(code) {
  const normalized = normalizeCrockford(code);
  return normalized.slice(0, 4) + '-' + normalized.slice(4);
}
function codeDigest(normalizedCode, key = process.env.PAIRING_HMAC_KEY) {
  if (!key) throw new FamilyError('internal');
  return createHmac('sha256', key).update('pairing-code:' + normalizedCode).digest('hex');
}
function secret() { return randomBytes(32).toString('base64url'); }
function hash(value) { return createHash('sha256').update(value).digest('hex'); }
function matches(token, digest) {
  if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token) || typeof digest !== 'string' || !/^[a-f0-9]{64}$/.test(digest)) return false;
  return timingSafeEqual(Buffer.from(hash(token), 'hex'), Buffer.from(digest, 'hex'));
}
function profile(user) {
  const google = user.providerData?.find(p => p.providerId === 'google.com');
  if (!google || user.disabled || !user.emailVerified) throw new FamilyError('unauthenticated');
  const photo = google.photoURL || user.photoURL;
  return { email: google.email || user.email || '', displayName: (google.displayName || user.displayName || google.email || '').slice(0, 160), photoUrl: typeof photo === 'string' && photo.startsWith('https://') ? photo : null };
}
module.exports = {codeDigest, CROCKFORD_ALPHABET, randomCrockford8, normalizeCrockford, formatCrockford8, FamilyError, requireGoogle, id, exact, secret, hash, matches, profile};
