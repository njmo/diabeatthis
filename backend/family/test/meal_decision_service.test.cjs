'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {PlanMemoryStore} = require('./plan_memory_store.cjs');
const {createMealDecisionService} = require('../common/meal_decision_service.cjs');
const sourceId = 'a'.repeat(32), requestId = 'b'.repeat(32);
const answer = {type:'insulinThenWait',minutes:15,message:'',targetSuggestion:null};
function fixture() {
  const store = new PlanMemoryStore(); let time = 1000000;
  const put = (path, value) => store.values.set(path,value);
  put('families/f', {childUid:'child',memberUids:['child','one','two'],managerUids:['one','two']});
  for (const [uid,role] of [['child','child'],['one','managingCaregiver'],['two','managingCaregiver']]) {
    put(`familyAccounts/${uid}`, {familyId:'f',role}); put(`families/f/members/${uid}`,{role,displayName:uid});
  }
  put('userMirrors/child',{sourceId});
  put('userMirrors/child/entities/meals_1',{kind:'meals',revision:1,deleted:false,payload:{name:'Lunch',status:'planned',purpose:'meal'}});
  const service = createMealDecisionService({store,now:()=>time});
  const call = (uid, action, fields={}) => service.execute(uid,{action,...fields});
  const create = () => call('child','create',{requestId,mealId:'1',sourceId,timeoutFallback:'manual'});
  const enable = uid => call(uid,'configure',{enabled:true});
  return {store,put,call,create,enable,advance:ms=>{time+=ms;}};
}
const rejected = (promise, code) => assert.rejects(promise,e=>e.code===code);
test('only current child can create a request for a current planned meal',async()=>{
  const f=fixture(); await rejected(f.call('outsider','fetch'),'permission-denied');
  await rejected(f.call('one','create',{requestId,mealId:'1',sourceId,timeoutFallback:'manual'}),'permission-denied');
  await rejected(f.call('child','create',{requestId,mealId:'1',sourceId:'c'.repeat(32),timeoutFallback:'manual'}),'failed-precondition');
  f.put('userMirrors/child/entities/meals_1',{kind:'meals',revision:1,deleted:false,payload:{status:'planned',purpose:'snack'}});
  await rejected(f.create(),'failed-precondition');
});
test('opt-in, simultaneous claim and lease expiry protect ownership',async()=>{
  const f=fixture(); await f.create(); await rejected(f.call('one','claim',{requestId}),'permission-denied');
  await f.enable('one'); await f.enable('two');
  const claims=await Promise.allSettled([f.call('one','claim',{requestId}),f.call('two','claim',{requestId})]);
  assert.equal(claims.filter(r=>r.status==='fulfilled').length,1);
  await rejected(f.call('two','respond',{requestId,decision:answer}),'failed-precondition');
  f.advance(30001); await f.call('two','claim',{requestId});
  await rejected(f.call('one','heartbeat',{requestId,stage:'decision',present:true}),'failed-precondition');
  await f.call('two','heartbeat',{requestId,stage:'decision',present:true});
  assert.equal((await f.call('child','fetch')).requests[0].stage,'decision');
});
test('decline is per caregiver and delegation validates membership and opt-in',async()=>{
  const f=fixture(); await f.enable('one'); await f.enable('two'); await f.create();
  await f.call('one','decline',{requestId}); await f.call('two','claim',{requestId});
  await rejected(f.call('two','delegate',{requestId,caregiverUid:'one'}),'failed-precondition');
  await rejected(f.call('two','delegate',{requestId,caregiverUid:'outsider'}),'failed-precondition');
  await f.call('two','respond',{requestId,decision:answer});
  assert.equal((await f.call('child','fetch')).requests[0].status,'answered');
});
test('delegate transfers ownership and revoked members cannot respond',async()=>{
  const f=fixture(); await f.enable('one'); await f.enable('two'); await f.create(); await f.call('one','claim',{requestId});
  await f.call('one','delegate',{requestId,caregiverUid:'two'});
  await rejected(f.call('one','respond',{requestId,decision:answer}),'failed-precondition');
  f.store.values.delete('families/f/members/two');
  await rejected(f.call('two','respond',{requestId,decision:answer}),'permission-denied');
});
test('revision changes and stale mirror reject responses',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId});
  f.put('userMirrors/child/entities/meals_1',{kind:'meals',revision:2,deleted:false,payload:{status:'planned',purpose:'meal'}});
  await rejected(f.call('one','respond',{requestId,decision:answer}),'failed-precondition');
  f.put('userMirrors/child',{sourceId:'c'.repeat(32)});
  await rejected(f.call('one','respond',{requestId,decision:answer}),'failed-precondition');
});
test('deadline rejects late replies and reconstructs expiry without worker',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); f.advance(300000);
  await rejected(f.call('one','respond',{requestId,decision:answer}),'failed-precondition');
  assert.equal((await f.call('child','fetch')).requests[0].status,'expired');
  const result={source:'manual',decision:'eatThenInsulin',minutes:null,caregiverUid:null};
  await f.call('child','expire',{requestId,sourceId,outcome:result});
  await f.call('child','expire',{requestId,sourceId,outcome:result});
});
test('accepted receipt is idempotent and validates actual response and current caregiver',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer});
  const outcome={source:'caregiver',decision:'insulinThenWait',minutes:15,caregiverUid:'one'};
  const {acceptanceToken}=await f.call('child','prepareAcceptance',{requestId,sourceId});
  await rejected(f.call('child','acknowledge',{requestId,sourceId,acceptanceToken,outcome:{...outcome,minutes:16}}),'failed-precondition');
  await f.call('child','acknowledge',{requestId,sourceId,acceptanceToken,outcome});
  await f.call('child','acknowledge',{requestId,sourceId,acceptanceToken,outcome});
});
test('answered requests expire and cannot be acknowledged late',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer}); f.advance(300000);
  await rejected(f.call('child','prepareAcceptance',{requestId,sourceId}),'failed-precondition');
  await f.call('child','expire',{requestId,sourceId,outcome:{source:'manual',decision:'deferMeal',minutes:20,caregiverUid:null}});
});

test('notifications target opted-in members and child response only',async()=>{
  const f=fixture(); await f.enable('one'); await f.create();
  const jobs=()=>[...f.store.values.entries()].filter(([path])=>path.startsWith('familyMealDecisionNotifications/')).map(([,value])=>value);
  assert.deepEqual(jobs().map(j=>[j.recipientUid,j.kind]),[['one','request']]);
  await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer});
  assert.deepEqual(jobs().map(j=>[j.recipientUid,j.kind]),[['one','request'],['child','response']]);
});
test('revocation and opt-out after response prevent acceptance',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer});
  await f.call('one','configure',{enabled:false});
  await rejected(f.call('child','prepareAcceptance',{requestId,sourceId}),'failed-precondition');
});

test('prepared acceptance survives deadline and caregiver revocation within lease',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer});
  f.advance(299999); const {acceptanceToken}=await f.call('child','prepareAcceptance',{requestId,sourceId});
  f.advance(2); assert.equal((await f.call('child','fetch')).requests[0].status,'accepting');
  await rejected(f.call('child','expire',{requestId,sourceId,outcome:{source:'manual',decision:'deferMeal',minutes:20,caregiverUid:null}}),'failed-precondition');
  await f.call('one','configure',{enabled:false});
  const outcome={source:'caregiver',decision:'insulinThenWait',minutes:15,caregiverUid:'one'};
  await f.call('child','acknowledge',{requestId,sourceId,acceptanceToken,outcome});
  f.advance(60000); await f.call('child','acknowledge',{requestId,sourceId,acceptanceToken,outcome});
});

test('reservation remains durable after lease and can be explicitly aborted only with token',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer});
  const {acceptanceToken}=await f.call('child','prepareAcceptance',{requestId,sourceId}); f.advance(900000);
  assert.equal((await f.call('child','fetch')).requests[0].status,'accepting');
  assert.equal((await f.call('child','prepareAcceptance',{requestId,sourceId})).acceptanceToken,acceptanceToken);
  const outcome={source:'manual',decision:'deferMeal',minutes:20,caregiverUid:null};
  await rejected(f.call('child','expire',{requestId,sourceId,outcome}),'failed-precondition');
  await rejected(f.call('one','expire',{requestId,sourceId,acceptanceToken,outcome}),'permission-denied');
  await f.call('child','abortAcceptance',{requestId,sourceId,acceptanceToken});
  await f.call('child','expire',{requestId,sourceId,outcome});
});
test('acknowledges local success after extended offline time',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer});
  const {acceptanceToken}=await f.call('child','prepareAcceptance',{requestId,sourceId}); f.advance(900000);
  await f.call('child','acknowledge',{requestId,sourceId,acceptanceToken,outcome:{source:'caregiver',decision:'insulinThenWait',minutes:15,caregiverUid:'one'}});
});
test('manual fallback override respects the captured manual permission',async()=>{
  const f=fixture(); await f.call('child','create',{requestId,mealId:'1',sourceId,timeoutFallback:'app',allowManualDecision:true}); f.advance(300000);
  await f.call('child','expire',{requestId,sourceId,outcome:{source:'manual',decision:'deferMeal',minutes:20,caregiverUid:null}});
  const g=fixture(); await g.call('child','create',{requestId,mealId:'1',sourceId,timeoutFallback:'app',allowManualDecision:false}); g.advance(300000);
  await rejected(g.call('child','expire',{requestId,sourceId,outcome:{source:'manual',decision:'deferMeal',minutes:20,caregiverUid:null}}),'failed-precondition');
  await g.call('child','expire',{requestId,sourceId,outcome:{source:'mealAdvisor',decision:'deferMeal',minutes:20,caregiverUid:null}});
  const h=fixture(); await rejected(h.call('child','create',{requestId,mealId:'1',sourceId,timeoutFallback:'manual',allowManualDecision:false}),'invalid-argument');
});
test('deferring a meal requires a bounded duration',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId});
  await rejected(f.call('one','respond',{requestId,decision:{...answer,type:'deferMeal',minutes:null}}),'invalid-argument');
  await rejected(f.call('one','respond',{requestId,decision:{...answer,type:'deferMeal',minutes:181}}),'invalid-argument');
  await f.call('one','respond',{requestId,decision:{...answer,type:'deferMeal',minutes:45}});
});
test('app decision remains available when a previously manual fallback is disabled locally',async()=>{
  const f=fixture(); await f.call('child','create',{requestId,mealId:'1',sourceId,timeoutFallback:'manual',allowManualDecision:true}); f.advance(300000);
  await f.call('child','expire',{requestId,sourceId,outcome:{source:'mealAdvisor',decision:'insulinAndEat',minutes:null,caregiverUid:null}});
});
test('only child with acceptance token may abort an uncommitted reservation',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer});
  const {acceptanceToken}=await f.call('child','prepareAcceptance',{requestId,sourceId});
  await rejected(f.call('child','abortAcceptance',{requestId,sourceId,acceptanceToken:'d'.repeat(32)}),'permission-denied');
  await rejected(f.call('one','abortAcceptance',{requestId,sourceId,acceptanceToken}),'permission-denied');
  await f.call('child','abortAcceptance',{requestId,sourceId,acceptanceToken});
  await f.call('child','abortAcceptance',{requestId,sourceId,acceptanceToken});
  const row=(await f.call('child','fetch')).requests[0];
  assert.equal(row.status,'expired'); assert.equal(row.outcome,null);
  await rejected(f.call('child','expire',{requestId,sourceId,outcome:{source:'manual',decision:'insulinAndEat',minutes:null,caregiverUid:null}}),'failed-precondition');
  f.advance(300000);
  await f.call('child','expire',{requestId,sourceId,outcome:{source:'manual',decision:'insulinAndEat',minutes:null,caregiverUid:null}});
  assert.equal((await f.call('child','fetch')).requests[0].outcome.source,'manual');
});
test('an already accepted decision cannot be aborted',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer});
  const {acceptanceToken}=await f.call('child','prepareAcceptance',{requestId,sourceId});
  await f.call('child','acknowledge',{requestId,sourceId,acceptanceToken,outcome:{source:'caregiver',decision:'insulinThenWait',minutes:15,caregiverUid:'one'}});
  await rejected(f.call('child','abortAcceptance',{requestId,sourceId,acceptanceToken}),'failed-precondition');
});
test('background retains caregiver identity while presence and claim expire independently',async()=>{
  const f=fixture(); await f.enable('one'); await f.enable('two'); await f.create(); await f.call('one','claim',{requestId});
  await f.call('one','heartbeat',{requestId,stage:'decision',present:false});
  let row=(await f.call('child','fetch')).requests[0];
  assert.equal(row.claimedByUid,'one'); assert.equal(row.claimedByName,'one'); assert.equal(row.presentUntil,0); assert.equal(row.stage,'decision'); assert.equal(row.claimAvailable,false);
  await rejected(f.call('two','claim',{requestId}),'failed-precondition');
  f.advance(30001); row=(await f.call('child','fetch')).requests[0];
  assert.equal(row.claimedByUid,'one'); assert.equal(row.presentUntil,0); assert.equal(row.claimAvailable,true);
  await f.call('one','heartbeat',{requestId,stage:'decision',present:true});
  row=(await f.call('child','fetch')).requests[0]; assert.equal(row.claimedByUid,'one'); assert.ok(row.presentUntil>0); assert.equal(row.claimAvailable,false);
  f.advance(30001);
  const results=await Promise.allSettled([f.call('one','heartbeat',{requestId,stage:'decision',present:true}),f.call('two','claim',{requestId})]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  row=(await f.call('child','fetch')).requests[0]; assert.ok(['one','two'].includes(row.claimedByUid)); assert.equal(row.claimAvailable,false);
  if(row.claimedByUid==='two') await rejected(f.call('one','heartbeat',{requestId,stage:'decision',present:true}),'failed-precondition');
});
test('concurrent request IDs share one active slot and notify caregivers only once',async()=>{
  const f=fixture(); await f.enable('one'); await f.enable('two');
  const otherId='d'.repeat(32);
  const [first,second]=await Promise.all([f.create(),f.call('child','create',{requestId:otherId,mealId:'1',sourceId,timeoutFallback:'app',allowManualDecision:false})]);
  assert.equal(first.requestId,second.requestId);
  const decisions=[...f.store.values.keys()].filter(path=>path.startsWith('userMirrors/child/mealDecisions/'));
  const jobs=[...f.store.values.keys()].filter(path=>path.startsWith('familyMealDecisionNotifications/'));
  assert.equal(decisions.length,1); assert.equal(jobs.length,2);
});
test('slot allows a new request after expiry but keeps reserved acceptance',async()=>{
  const f=fixture(); await f.enable('one'); await f.create(); await f.call('one','claim',{requestId}); await f.call('one','respond',{requestId,decision:answer});
  await f.call('child','prepareAcceptance',{requestId,sourceId}); f.advance(300001);
  const otherId='d'.repeat(32);
  assert.equal((await f.call('child','create',{requestId:otherId,mealId:'1',sourceId,timeoutFallback:'app'})).requestId,requestId);
});
test('expired slot may be replaced with a new request',async()=>{
  const f=fixture(); await f.create(); f.advance(300001); const otherId='d'.repeat(32);
  assert.equal((await f.call('child','create',{requestId:otherId,mealId:'1',sourceId,timeoutFallback:'app'})).requestId,otherId);
});
