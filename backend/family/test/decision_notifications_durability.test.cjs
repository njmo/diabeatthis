'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {MemoryStore} = require('./memory_store.cjs');
const {createDecisionNotifications} = require('../common/decision_notifications.cjs');

function fixture(send) {
  const store = new MemoryStore();
  let time = 1000;
  const service = createDecisionNotifications({store, now: () => time, messaging: {sendEachForMulticast: send}});
  store.values.set('userMirrors/child/mealDecisions/request', {familyId:'family', status:'open', deadline:500000, declinedUids:[]});
  store.values.set('families/family', {childUid:'child', memberUids:['child','carer'], managerUids:['carer']});
  store.values.set('familyAccounts/carer', {familyId:'family',role:'managingCaregiver'});
  store.values.set('families/family/members/carer', {role:'managingCaregiver'});
  store.values.set('familyMealDecisionPreferences/carer', {enabled:true});
  store.values.set('familyMealDecisionPreferences/carer/devices/a', {token:'token'});
  return {store, service, advance: ms => {time += ms;}, job: {childUid:'child',recipientUid:'carer',requestId:'request'}};
}

test('active lease retries; abandoned lease can be claimed and completed', async () => {
  let sent = 0;
  const {store,service,advance,job} = fixture(async () => {sent++; return {responses:[{success:true}]};});
  store.values.set('familyMealDecisionDispatches/job', {status:'sending',leaseId:'dead-process',leaseUntil:121000});
  await assert.rejects(service.dispatch('job',job), /already in progress/);
  assert.equal(sent,0);
  advance(120001);
  await service.dispatch('job',job);
  assert.equal(sent,1);
  assert.equal(store.values.get('familyMealDecisionDispatches/job').status,'sent');
  await service.dispatch('job',job);
  assert.equal(sent,1);
});

test('transient delivery failure clears own lease so a retry can send', async () => {
  let attempts = 0;
  const {store,service,job} = fixture(async () => {
    attempts++;
    return {responses:[attempts === 1 ? {success:false,error:{code:'messaging/internal-error'}} : {success:true}]};
  });
  await assert.rejects(service.dispatch('job',job));
  assert.equal(store.values.has('familyMealDecisionDispatches/job'),false);
  await service.dispatch('job',job);
  assert.equal(attempts,2);
  assert.equal(store.values.get('familyMealDecisionDispatches/job').status,'sent');
});
