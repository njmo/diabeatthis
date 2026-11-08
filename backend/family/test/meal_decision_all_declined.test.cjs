'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {PlanMemoryStore} = require('./plan_memory_store.cjs');
const {createMealDecisionService} = require('../common/meal_decision_service.cjs');

const sourceId = 'a'.repeat(32), requestId = 'b'.repeat(32);
const manual = {source:'manual',decision:'eatThenInsulin',minutes:null,caregiverUid:null};
const app = {source:'mealAdvisor',decision:'insulinAndEat',minutes:null,caregiverUid:null};
const response = {type:'insulinAndEat',minutes:null,message:'',targetSuggestion:null};
const rejected = (promise, code='failed-precondition') => assert.rejects(promise, error => error.code === code);

function fixture() {
  const store = new PlanMemoryStore();
  const put = (path, value) => store.values.set(path, value);
  put('families/f', {childUid:'child',memberUids:['child','one','two'],managerUids:['one','two']});
  for (const [uid, role] of [['child','child'],['one','managingCaregiver'],['two','managingCaregiver']]) {
    put(`familyAccounts/${uid}`, {familyId:'f',role});
    put(`families/f/members/${uid}`, {role,displayName:uid});
  }
  put('userMirrors/child',{sourceId});
  put('userMirrors/child/entities/meals_1',{kind:'meals',revision:1,deleted:false,payload:{name:'Lunch',status:'planned',purpose:'meal'}});
  const service = createMealDecisionService({store,now:()=>1000000});
  const call = (uid,action,fields={}) => service.execute(uid,{action,...fields});
  const enable = uid => call(uid,'configure',{enabled:true});
  const create = (extra={}) => call('child','create',{requestId,mealId:'1',sourceId,timeoutFallback:'app',...extra});
  return {store,call,enable,create};
}

test('last enabled caregiver declining immediately expires and permits one durable fallback', async () => {
  const f = fixture();
  await f.enable('one'); await f.enable('two'); await f.create();
  await f.call('one','decline',{requestId});
  let row = (await f.call('child','fetch')).requests[0];
  assert.equal(row.status,'waiting');
  await rejected(f.call('child','expire',{requestId,sourceId,outcome:app}));
  await f.call('two','decline',{requestId});
  row = (await f.call('child','fetch')).requests[0];
  assert.equal(row.status,'expired');
  assert.equal(row.terminalReason,'allCaregiversDeclined');
  assert.equal(row.outcome,null);
  assert.deepEqual(row.members.map(member => member.status),['declined','declined']);
  assert.ok(row.deadline > 1000000);
  await rejected(f.call('one','claim',{requestId}));
  await rejected(f.call('two','respond',{requestId,decision:response}));
  const saved = await f.call('child','expire',{requestId,sourceId,outcome:app});
  assert.deepEqual(saved.outcome,app);
  await f.call('child','expire',{requestId,sourceId,outcome:app});
  await rejected(f.call('child','expire',{requestId,sourceId,outcome:manual}));
  const jobs = [...f.store.values.values()].filter(value => value?.recipientUid === 'child' && value.kind === 'response');
  assert.equal(jobs.length,1);
});

test('disabled caregivers do not hold up fallback and manual permission remains enforced', async () => {
  const f = fixture();
  await f.enable('one'); await f.create({allowManualDecision:false});
  await f.call('one','decline',{requestId});
  const row = (await f.call('child','fetch')).requests[0];
  assert.equal(row.status,'expired');
  assert.deepEqual(row.members.map(member => member.status),['declined','disabled']);
  await rejected(f.call('child','expire',{requestId,sourceId,outcome:manual}));
  await f.call('child','expire',{requestId,sourceId,outcome:app});
});

test('response and prepared acceptance cannot be replaced by late declines or early fallback', async () => {
  const f = fixture();
  await f.enable('one'); await f.enable('two'); await f.create();
  await f.call('one','claim',{requestId});
  await f.call('one','respond',{requestId,decision:response});
  await rejected(f.call('two','decline',{requestId}));
  await rejected(f.call('child','expire',{requestId,sourceId,outcome:app}));
  await f.call('child','prepareAcceptance',{requestId,sourceId});
  await rejected(f.call('two','decline',{requestId}));
  await rejected(f.call('child','expire',{requestId,sourceId,outcome:app}));
  assert.equal((await f.call('child','fetch')).requests[0].status,'accepting');
});

test('concurrent final declines retain both roster entries and publish one terminal notification', async () => {
  const f = fixture();
  await f.enable('one'); await f.enable('two'); await f.create();
  const results = await Promise.allSettled([
    f.call('one','decline',{requestId}),
    f.call('two','decline',{requestId}),
  ]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length,2);
  const row = (await f.call('child','fetch')).requests[0];
  assert.equal(row.status,'expired');
  assert.deepEqual(row.members.map(member => member.status),['declined','declined']);
  const jobs = [...f.store.values.values()].filter(value => value?.recipientUid === 'child' && value.kind === 'response');
  assert.equal(jobs.length,1);
});
