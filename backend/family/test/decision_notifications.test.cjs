'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {MemoryStore} = require('./memory_store.cjs');
const {createDecisionNotifications} = require('../common/decision_notifications.cjs');

function fixture() {
  const store = new MemoryStore();
  const messages = [];
  const service = createDecisionNotifications({store, now: () => 1000, messaging: {sendEachForMulticast: async message => messages.push(message)}});
  const put = (path, value) => store.values.set(path, value);
  put('userMirrors/child/mealDecisions/request', {familyId:'family', status:'open', deadline:3000, declinedUids:[]});
  put('families/family', {childUid:'child', memberUids:['child','carer'], managerUids:['carer']});
  put('familyAccounts/carer', {familyId:'family', role:'managingCaregiver'});
  put('families/family/members/carer', {role:'managingCaregiver'});
  put('familyMealDecisionPreferences/carer', {enabled:true});
  put('familyMealDecisionPreferences/carer/devices/a', {token:'device-token'});
  return {store, service, messages, job: {childUid:'child', recipientUid:'carer', requestId:'request'}};
}

test('sends only opaque ID, bounds TTL, and ignores duplicate jobs', async () => {
  const {service,messages,job} = fixture();
  await service.dispatch('job',job);
  await service.dispatch('job',job);
  assert.equal(messages.length,1);
  assert.deepEqual(messages[0].data,{requestId:'request'});
  assert.deepEqual(messages[0].android,{priority:'high',ttl:2000});
});

test('rechecks current membership, opt-in, deadline and request state', async () => {
  for (const [path, value] of [
    ['familyMealDecisionPreferences/carer',{enabled:false}],
    ['familyAccounts/carer',{familyId:'other',role:'managingCaregiver'}],
    ['families/family/members/carer',{role:'child'}],
    ['families/family',{childUid:'child', memberUids:['child'], managerUids:[]}],
    ['userMirrors/child/mealDecisions/request',{familyId:'family', status:'open',deadline:1000}],
    ['userMirrors/child/mealDecisions/request',{familyId:'family', status:'responded',deadline:3000}],
    ['userMirrors/child/mealDecisions/request',{familyId:'family', status:'open',deadline:3000,declinedUids:['carer']}],
  ]) {
    const {store,service,messages,job} = fixture();
    store.values.set(path,value);
    await service.dispatch('job',job);
    assert.equal(messages.length,0,path);
  }
});

test('child response notification requires current child membership and mirror source', async () => {
  const {store,service,messages} = fixture();
  store.values.set('userMirrors/child', {sourceId:'current'});
  store.values.set('userMirrors/child/mealDecisions/request', {familyId:'family',sourceId:'current',status:'responded',deadline:3000});
  store.values.set('familyAccounts/child', {familyId:'family',role:'child'});
  store.values.set('families/family/members/child', {role:'child'});
  store.values.set('familyMealDecisionPreferences/child', {enabled:true});
  store.values.set('familyMealDecisionPreferences/child/devices/a', {token:'child-token'});
  const job = {childUid:'child',recipientUid:'child',requestId:'request',kind:'response'};
  await service.dispatch('childJob',job);
  assert.equal(messages.length,1);
  store.values.set('userMirrors/child', {sourceId:'replaced'});
  await service.dispatch('otherJob',job);
  assert.equal(messages.length,1);
});

test('registration is device scoped and does not alter account consent', async () => {
  const {store,service} = fixture();
  const token = 'a'.repeat(32);
  store.values.set('familyMealDecisionPreferences/carer', {enabled:false});
  await service.register('carer', {enabled:true, token});
  assert.equal(store.values.get('familyMealDecisionPreferences/carer').enabled,false);
  const devices = [...store.values.keys()].filter(path => path.startsWith('familyMealDecisionPreferences/carer/devices/'));
  assert.equal(devices.length,2);
  await service.register('carer', {enabled:false, token});
  assert.equal([...store.values.keys()].filter(path => path.startsWith('familyMealDecisionPreferences/carer/devices/')).length,1);
  await assert.rejects(service.register('carer', {enabled:true,token,recipientUid:'other'}));
  store.values.set('families/family', {childUid:'child',memberUids:['child'],managerUids:[]});
  await assert.rejects(service.register('carer', {enabled:true,token}));
});
