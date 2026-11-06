'use strict';
const { createHash, randomBytes, timingSafeEqual } = require('node:crypto');
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
module.exports = {FamilyError, requireGoogle, id, exact, secret, hash, matches, profile};
