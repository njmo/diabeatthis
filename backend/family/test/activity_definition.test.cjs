'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {PlanMemoryStore}=require('./plan_memory_store.cjs');
const {createFamilyService}=require('../common/family_service.cjs');
const {createMirrorService}=require('../common/mirror_service.cjs');
const {createPlanService}=require('../common/plan_service.cjs');
const {validatePlan}=require('../common/plan_contract.cjs');
const sourceId='a'.repeat(32);
async function fixture(){
  const store=new PlanMemoryStore();
  const family=createFamilyService({store,auth:{getUser:async uid=>({emailVerified:true,providerData:[{providerId:'google.com',displayName:uid}]})}});
  const invite=await family.createInvite('child',{});
  await family.requestJoin('parent',{inviteId:invite.id,token:invite.token});
  await family.decide('child',{inviteId:invite.id,approve:true});
  const mirror=createMirrorService({store});await mirror.register('child',{sourceId,activityCommandsVersion:2});
  return {mirror,plans:createPlanService({store}),plan:{id:'b'.repeat(32),sourceId,type:'planActivity',targetId:null,expected:[],values:{activityId:null,activity:{name:'Walk',percentagePre:20,percentagePost:30,durationMinutes:30},startedAt:Date.now()+3600000,durationMinutes:30}}};
}
test('inline definitions require capable child, stay private, and older children cannot claim them',async()=>{
  const {mirror,plans,plan}=await fixture();
  await mirror.register('child',{sourceId,activityCommandsVersion:1});
  await assert.rejects(plans.submit('parent',plan));
  await mirror.register('child',{sourceId,activityCommandsVersion:2});
  await assert.rejects(plans.submit('stranger',plan));
  await plans.submit('parent',plan);
  assert.equal((await plans.fetch('child',{})).plans.length,0);
  assert.equal((await plans.fetch('child',{activityCommandsVersion:1})).plans.length,0);
  assert.equal((await plans.fetch('child',{activityCommandsVersion:2})).plans.length,1);
  await assert.rejects(plans.claim('child',{id:plan.id,sourceId,activityCommandsVersion:1}));
  assert.equal((await plans.claim('child',{id:plan.id,sourceId,activityCommandsVersion:2})).values.activity.name,'Walk');
});
test('definition accepts only reviewed fields, valid name, sensitivity and duration',async()=>{
  const {plan}=await fixture();
  assert.doesNotThrow(()=>validatePlan(plan));
  for(const activity of [
    {...plan.values.activity,name:'a'}, {...plan.values.activity,name:'a'.repeat(31)},
    {...plan.values.activity,percentagePre:0}, {...plan.values.activity,percentagePost:100},
    {...plan.values.activity,durationMinutes:1441}, {...plan.values.activity,id:77},
  ])assert.throws(()=>validatePlan({...plan,values:{...plan.values,activity}}));
  assert.throws(()=>validatePlan({...plan,values:{...plan.values,activityId:1}}));
});
