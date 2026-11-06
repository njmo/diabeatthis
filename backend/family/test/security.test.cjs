'use strict';
const test = require('node:test'); const assert = require('node:assert/strict');
const {requireGoogle, secret, hash, matches} = require('../common/security.cjs');
test('requires verified Google identity and App Check; rejects forged providers and consumed tokens', () => {
  const valid = {auth: {uid: 'child', token: {email_verified: true, firebase: {sign_in_provider: 'google.com'}}}, app: {appId: 'test'}};
  assert.equal(requireGoogle(valid), 'child');
  for (const request of [{}, {...valid, app: null}, {...valid, app: {alreadyConsumed: true}}, {...valid, auth: {...valid.auth, token: {firebase: {sign_in_provider: 'password'}}}}]) assert.throws(() => requireGoogle(request));
});
test('256-bit tokens are hashed and comparisons reject malformed secrets', () => {
  const token = secret(); assert.equal(token.length, 43); assert.ok(matches(token, hash(token)));
  assert.equal(matches(secret(), hash(token)), false); assert.equal(matches(token, 'bad'), false);
});
