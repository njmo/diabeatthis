'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
const {MemoryStore} = require('./memory_store.cjs');
const {createDecisionNotifications} = require('../common/decision_notifications.cjs');

test('unpaired account can revoke only its own device binding', async () => {
  const store = new MemoryStore();
  const service = createDecisionNotifications({store, messaging:{}});
  const token = 'a'.repeat(32);
  const id = createHash('sha256').update(token).digest('hex');
  const binding = `familyMealDecisionDeviceBindings/${id}`;
  const device = `familyMealDecisionPreferences/owner/devices/${id}`;
  store.values.set(binding, {uid:'owner'});
  store.values.set(device, {token});
  await service.register('outsider', {enabled:false, token});
  assert.equal(store.values.has(device),true);
  assert.equal(store.values.get(binding).uid,'owner');
  await service.register('owner', {enabled:false,token});
  assert.equal(store.values.has(device),false);
  assert.equal(store.values.has(binding),false);
  await assert.rejects(service.register('owner', {enabled:true,token}));
});
