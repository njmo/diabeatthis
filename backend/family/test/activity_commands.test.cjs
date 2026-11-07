'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {PlanMemoryStore}=require('./plan_memory_store.cjs');
const {createFamilyService}=require('../common/family_service.cjs');
const {createMirrorService}=require('../common/mirror_service.cjs');
const {createPlanService}=require('../common/plan_service.cjs');
const {validatePlan}=require('../common/plan_contract.cjs');
const sourceId='a'.repeat(32);
async function fixture(capable=true){
  const store=new PlanMemoryStore();
  const family=createFamilyService({store,auth:{getUser:async uid=>({emailVerified:true,providerData:[{providerId:'google.com',displayName:uid}]})}});
  const invite=await family.createInvite('child',{});
  await family.requestJoin('parent',{inviteId:invite.id,token:invite.token});
  await family.decide('child',{inviteId:invite.id,approve:true});
  const mirror=createMirrorService({store});
  await mirror.register('child',{sourceId,...(capable?{activityCommandsVersion:1}:{})});
  const activity={kind:'activities',id:'1',revision:1,deleted:false,payload:{id:1,name:'Walk'}};
  store.values.set('userMirrors/child/entities/activities_1',activity);
  const plan={id:'b'.repeat(32),sourceId,type:'startActivity',targetId:null,expected:[{kind:'activities',id:'1',revision:1}],values:{activityId:1,startedAt:Date.now()}};
  return {store,mirror,plans:createPlanService({store}),plan};
}
test('new commands require an upgraded child and cannot be self-enabled by caregiver',async()=>{
  const {plans,plan,mirror}=await fixture(false);
  await assert.rejects(plans.submit('parent',plan),e=>e.code==='failed-precondition');
  await assert.rejects(mirror.register('parent',{sourceId,activityCommandsVersion:1}));
  await mirror.register('child',{sourceId,activityCommandsVersion:1});
  assert.equal((await plans.submit('parent',plan)).status,'pending');
});
test('start is family scoped, globally locked until child confirms, and canonical result is a log',async()=>{
  const {plans,plan,store}=await fixture();
  await assert.rejects(plans.submit('stranger',plan));
  await plans.submit('parent',plan);
  await assert.rejects(plans.submit('parent',{...plan,id:'c'.repeat(32)}));
  assert.equal((await plans.fetch('child',{})).plans.length,0);
  assert.equal((await plans.fetch('child',{activityCommandsVersion:1})).plans.length,1);
  await assert.rejects(plans.claim('child',{id:plan.id,sourceId}));
  const claim=await plans.claim('child',{id:plan.id,sourceId,activityCommandsVersion:1});
  const ack={id:plan.id,sourceId,claimToken:claim.claimToken,reason:null,resultId:7};
  await plans.acknowledge('child',{...ack,outcome:'prepared'});
  const result={kind:'activityLogs',id:'7',revision:1,deleted:false,payload:{id:7,activity_id:1,started_at:Date.now(),ended_at:null}};
  store.values.set('userMirrors/child/entities/activityLogs_7',result);
  await plans.acknowledge('child',{...ack,outcome:'applied'});
  const saved=(await plans.fetch('parent',{})).plans[0];
  assert.equal(saved.status,'applied');
  assert.equal(saved.canonical[0].kind,'activityLogs');
});
test('historical and immediate commands reject invalid time ranges and execution fields',async()=>{
  const {plan}=await fixture();
  for(const values of [
    {activityId:1,startedAt:Date.now()+60000},
    {activityId:1,startedAt:Date.now()-300001},
    {...plan.values,endedAt:Date.now()},
  ])assert.throws(()=>validatePlan({...plan,values}));
  const history={...plan,type:'logActivity',values:{activityId:1,startedAt:Date.now()-3600000,endedAt:Date.now()-1800000}};
  assert.doesNotThrow(()=>validatePlan(history));
  assert.throws(()=>validatePlan({...history,values:{...history.values,endedAt:Date.now()+60000}}));
});
