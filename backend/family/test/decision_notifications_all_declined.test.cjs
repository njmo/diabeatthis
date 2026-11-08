'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {MemoryStore} = require('./memory_store.cjs');
const {createDecisionNotifications} = require('../common/decision_notifications.cjs');

function fixture() {
  const store = new MemoryStore(), messages = [];
  const put = (path,value) => store.values.set(path,value);
  put('userMirrors/child',{sourceId:'current'});
  put('userMirrors/child/mealDecisions/request',{familyId:'family',sourceId:'current',status:'expired',terminalReason:'allCaregiversDeclined',outcome:null,deadline:3000});
  put('families/family',{childUid:'child',memberUids:['child','carer'],managerUids:['carer']});
  put('familyAccounts/child',{familyId:'family',role:'child'});
  put('families/family/members/child',{role:'child'});
  put('familyMealDecisionPreferences/child/devices/a',{token:'child-token'});
  const service = createDecisionNotifications({store,now:()=>1000,messaging:{sendEachForMulticast:async message => { messages.push(message); return {responses:[{success:true}]}; }}});
  return {store,messages,service,job:{childUid:'child',recipientUid:'child',requestId:'request',kind:'response'}};
}

test('all-declined child notification is delivered once with bounded TTL', async () => {
  const {service,messages,job} = fixture();
  await service.dispatch('job',job);
  await service.dispatch('job',job);
  assert.equal(messages.length,1);
  assert.deepEqual(messages[0].data,{requestId:'request'});
  assert.equal(messages[0].android.ttl,2000);
});

test('terminal notification still requires current source, membership, deadline and outstanding fallback', async () => {
  for (const [path,value] of [
    ['userMirrors/child',{sourceId:'replaced'}],
    ['families/family',{childUid:'child',memberUids:['carer'],managerUids:['carer']}],
    ['familyAccounts/child',{familyId:'other',role:'child'}],
    ['families/family/members/child',{role:'managingCaregiver'}],
    ['userMirrors/child/mealDecisions/request',{familyId:'family',sourceId:'current',status:'expired',terminalReason:'allCaregiversDeclined',outcome:null,deadline:1000}],
    ['userMirrors/child/mealDecisions/request',{familyId:'family',sourceId:'current',status:'expired',terminalReason:'other',outcome:null,deadline:3000}],
    ['userMirrors/child/mealDecisions/request',{familyId:'family',sourceId:'current',status:'expired',terminalReason:'allCaregiversDeclined',outcome:{source:'mealAdvisor'},deadline:3000}],
  ]) {
    const {store,service,messages,job} = fixture();
    store.values.set(path,value);
    await service.dispatch('job',job);
    assert.equal(messages.length,0,path);
  }
});

test('expired all-declined requests cannot notify a caregiver as an open request', async () => {
  const {store,service,messages} = fixture();
  store.values.set('familyAccounts/carer',{familyId:'family',role:'managingCaregiver'});
  store.values.set('families/family/members/carer',{role:'managingCaregiver'});
  store.values.set('familyMealDecisionPreferences/carer',{enabled:true});
  store.values.set('familyMealDecisionPreferences/carer/devices/a',{token:'carer-token'});
  await service.dispatch('job',{childUid:'child',recipientUid:'carer',requestId:'request',kind:'request'});
  assert.equal(messages.length,0);
});
