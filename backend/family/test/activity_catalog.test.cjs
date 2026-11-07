'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {PlanMemoryStore}=require('./plan_memory_store.cjs');
const {createFamilyService}=require('../common/family_service.cjs');
const {createMirrorService}=require('../common/mirror_service.cjs');
const {createPlanService}=require('../common/plan_service.cjs');
const {validatePlan}=require('../common/plan_contract.cjs');
const sourceId='a'.repeat(32);
const activity={name:'Swimming',percentagePre:20,percentagePost:30,durationMinutes:30};
const schedule=()=>({weekdays:[1,3,5],startMinute:1020,durationMinutes:30,confirmationMode:'before',previousDayMinute:1140,validFrom:Date.now(),validUntil:null});
async function fixture(){
 const store=new PlanMemoryStore();const family=createFamilyService({store,auth:{getUser:async uid=>({emailVerified:true,providerData:[{providerId:'google.com',displayName:uid}]})}});
 const invite=await family.createInvite('child',{});await family.requestJoin('parent',{inviteId:invite.id,token:invite.token});await family.decide('child',{inviteId:invite.id,approve:true});
 const mirror=createMirrorService({store});await mirror.register('child',{sourceId,activityCommandsVersion:3});
 return {store,family,mirror,plans:createPlanService({store}),plan:{id:'b'.repeat(32),sourceId,type:'createActivity',targetId:null,expected:[],values:{activity,schedule:schedule()}}};
}
test('v3 catalog commands require capable child and family membership',async()=>{
 const {mirror,plans,plan}=await fixture();
 await mirror.register('child',{sourceId,activityCommandsVersion:2});await assert.rejects(plans.submit('parent',plan));
 await mirror.register('child',{sourceId,activityCommandsVersion:3});await assert.rejects(plans.submit('stranger',plan));await plans.submit('parent',plan);
 for(const version of [0,1,2]){const data=version?{activityCommandsVersion:version}:{};assert.equal((await plans.fetch('child',data)).plans.length,0);await assert.rejects(plans.claim('child',{id:plan.id,sourceId,...data}));}
 assert.equal((await plans.fetch('child',{activityCommandsVersion:3})).plans.length,1);
 assert.equal((await plans.claim('child',{id:plan.id,sourceId,activityCommandsVersion:3})).values.activity.name,'Swimming');
});
test('catalog contracts reject unsupported keys, ranges, and schedule ambiguity',async()=>{
 const {plan}=await fixture();assert.doesNotThrow(()=>validatePlan(plan));
 for(const patch of [{weekdays:[]},{weekdays:[1,1]},{weekdays:[8]},{durationMinutes:1441},{startMinute:1440},{confirmationMode:'other'},{validUntil:1},{ownerUid:'stranger'}])assert.throws(()=>validatePlan({...plan,values:{...plan.values,schedule:{...schedule(),...patch}}}));
 for(const type of ['updateActivity','createActivitySchedule'])assert.throws(()=>validatePlan({...plan,type}));
 assert.doesNotThrow(()=>validatePlan({...plan,type:'updateActivity',targetId:1}));
 assert.doesNotThrow(()=>validatePlan({...plan,type:'createActivitySchedule',targetId:1,values:{schedule:schedule()}}));
});
test('inline recurrence is gated at v3 as well as definitions',async()=>{
 const {plans,mirror,plan}=await fixture();const inline={...plan,type:'planActivity',values:{activityId:null,activity,startedAt:Date.now()+3600000,durationMinutes:30,schedule:schedule()}};
 await mirror.register('child',{sourceId,activityCommandsVersion:2});await assert.rejects(plans.submit('parent',inline));
 await mirror.register('child',{sourceId,activityCommandsVersion:3});await plans.submit('parent',inline);
 assert.equal((await plans.fetch('child',{activityCommandsVersion:2})).plans.length,0);
});
test('schedule ACK keeps activity and result schedule kinds distinct with colliding IDs',async()=>{
 const {store,plans,plan}=await fixture();
 const entity=(kind,id,payload)=>({kind,id:String(id),revision:1,sequence:1,deleted:false,payload:{id,...payload}});
 const target=entity('activities',9,activity);
 store.values.set('userMirrors/child/entities/activities_9',target);
 const command={...plan,type:'createActivitySchedule',targetId:9,expected:[{kind:'activities',id:'9',revision:1}],values:{schedule:schedule()}};
 await plans.submit('parent',command);
 const claim=await plans.claim('child',{id:plan.id,sourceId,activityCommandsVersion:3});
 store.values.set('userMirrors/child/entities/activitySchedules_5',entity('activitySchedules',5,{activity_id:9}));
 store.values.set('userMirrors/child/entities/activitySchedules_9',entity('activitySchedules',9,{activity_id:99}));
 const ack={id:plan.id,sourceId,reason:null,resultId:5,claimToken:claim.claimToken};
 await plans.acknowledge('child',{...ack,outcome:'prepared'});
 await plans.acknowledge('child',{...ack,outcome:'applied'});
 const saved=store.values.get(`userMirrors/child/plans/${plan.id}`);
 assert.deepEqual(saved.canonical.map(r=>`${r.kind}/${r.id}`).sort(),['activities/9','activitySchedules/5']);
});

test('pending activity writes exclude second caregiver and reject stale revision',async()=>{
 const {store,family,plans,plan}=await fixture();
 const invite=await family.createInvite('child',{});await family.requestJoin('second',{inviteId:invite.id,token:invite.token});await family.decide('parent',{inviteId:invite.id,approve:true});
 store.values.set('userMirrors/child/entities/activities_9',{kind:'activities',id:'9',revision:2,deleted:false,payload:{id:9,...activity}});
 const command={...plan,type:'updateActivity',targetId:9,expected:[{kind:'activities',id:'9',revision:1}],values:{activity,schedule:null}};
 await assert.rejects(plans.submit('parent',command));command.expected[0].revision=2;await plans.submit('parent',command);
 await assert.rejects(plans.submit('second',{...command,id:'c'.repeat(32)}));
});

test('inline recurrence cannot bypass per-activity serialization for existing IDs',async()=>{
 const {plan}=await fixture();
 for(const type of ['planActivity','startActivity','logActivity'])assert.throws(()=>validatePlan({...plan,type,values:{activityId:9,schedule:schedule(),startedAt:Date.now()+3600000,...(type==='planActivity'?{durationMinutes:30}:{}),...(type==='logActivity'?{endedAt:Date.now()+7200000}:{})}}));
});
