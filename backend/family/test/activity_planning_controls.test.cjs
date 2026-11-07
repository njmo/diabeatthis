'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {MemoryStore}=require('./memory_store.cjs');
const {createFamilyService}=require('../common/family_service.cjs');
const {createMirrorService}=require('../common/mirror_service.cjs');
const {createPlanService}=require('../common/plan_service.cjs');
const {scopeRows,versions}=require('../common/plan_contract.cjs');
class ActivityControlsStore extends MemoryStore {
 collection(path){const build=(filters=[],order=null,max=null)=>({path,query:true,doc:id=>this.doc(path+'/'+id),where:(field,operator,value)=>build([...filters,{field,operator,value}],order,max),orderBy:(field,direction='asc')=>build(filters,{field,direction},max),limit:count=>build(filters,order,count),filters,order,max});return build();}
 runTransaction(action){return super.runTransaction(tx=>action({...tx,get:async ref=>{const snap=await tx.get(ref);if(!ref.query)return snap;const value=(row,key)=>key.split('.').reduce((v,k)=>v?.[k],row);let docs=snap.docs.filter(doc=>(ref.filters??[]).every(f=>f.operator==='=='?value(doc.data(),f.field)===f.value:f.operator==='>'?value(doc.data(),f.field)>f.value:false));if(ref.order)docs.sort((a,b)=>(value(a.data(),ref.order.field)-value(b.data(),ref.order.field))*(ref.order.direction==='desc'?-1:1));if(ref.max!=null)docs=docs.slice(0,ref.max);return {docs};}}));}
}
const sourceId='a'.repeat(32);
async function fixture({phase='planned',near=false,stamp=false}={}) {
 const store=new ActivityControlsStore(),family=createFamilyService({store,auth:{getUser:async uid=>({emailVerified:true,providerData:[{providerId:'google.com',displayName:uid}]})}});
 const invite=await family.createInvite('child',{});await family.requestJoin('parent',{inviteId:invite.id,token:invite.token});await family.decide('child',{inviteId:invite.id,approve:true});
 const mirror=createMirrorService({store});await mirror.register('child',{sourceId,activityCommandsVersion:4});
 const now=Date.now(),start=now+(near?30*60000:4*86400000);
 const rows=[];const add=(kind,id,payload)=>{const row={kind,id:String(id),revision:1,sequence:1,deleted:false,payload:{id,...payload}};rows.push(row);store.values.set(`userMirrors/child/entities/${kind}_${id}`,row);return row;};
 add('activities',1,{name:'Training'});add('activitySchedules',5,{activity_id:1,enabled:1});
 add('activityLogs',7,{activity_id:1,started_at:start,ended_at:null});
 add('activityOccurrences',9,{activity_id:1,schedule_id:5,started_at:start,status:'planned',activity_log_id:7,target_requested_at:stamp?now:null});
 add('workflowLocks',1,{kind:'activity',entity_id:7,phase,active:1});
 const plan=(type,id='b'.repeat(32))=>{const p={id,sourceId,type,targetId:type==='setActivityScheduleEnabled'?5:9,values:type==='moveActivity'?{startedAt:start+3600000}:type==='setActivityScheduleEnabled'?{enabled:false,effectiveFrom:now}:{}};p.expected=versions(scopeRows(rows,p));return p;};
 return {store,family,mirror,plans:createPlanService({store}),rows,add,plan};
}
for(const type of ['skipActivity','moveActivity','setActivityScheduleEnabled']) {
 test(`${type} permits distant planned phase even with legacy early target stamp`,async()=>{const f=await fixture({stamp:true});assert.equal((await f.plans.submit('parent',f.plan(type))).status,'pending');});
 for(const props of [{phase:'preparing'},{near:true,stamp:true}])test(`${type} blocks actual preparation ${JSON.stringify(props)}`,async()=>{const f=await fixture(props);await assert.rejects(f.plans.submit('parent',f.plan(type)));});
 test(`${type} is private to family`,async()=>{const f=await fixture();await assert.rejects(f.plans.submit('stranger',f.plan(type)));});
}
test('v4 skip and activation never reach v3 child runners',async()=>{
 for(const type of ['skipActivity','setActivityScheduleEnabled']){const f=await fixture();await f.mirror.register('child',{sourceId,activityCommandsVersion:3});await assert.rejects(f.plans.submit('parent',f.plan(type)));await f.mirror.register('child',{sourceId,activityCommandsVersion:4});await f.plans.submit('parent',f.plan(type));assert.equal((await f.plans.fetch('child',{activityCommandsVersion:3})).plans.length,0);assert.equal((await f.plans.fetch('child',{activityCommandsVersion:4})).plans.length,1);}
});
test('activation ignores more than 250 historical occurrences',async()=>{const f=await fixture();for(let i=20;i<400;i++)f.add('activityOccurrences',i,{activity_id:1,schedule_id:5,started_at:Date.now()-86400000*i,status:'recorded',activity_log_id:null});const p=f.plan('setActivityScheduleEnabled');assert.equal(p.expected.length,4);assert.equal((await f.plans.submit('parent',p)).status,'pending');});
for(const order of [['skipActivity','setActivityScheduleEnabled'],['setActivityScheduleEnabled','moveActivity']])test(`schedule vs occurrence locks serialize ${order.join(' then ')}`,async()=>{const f=await fixture();await f.plans.submit('parent',f.plan(order[0]));await assert.rejects(f.plans.submit('parent',f.plan(order[1],'c'.repeat(32))));});
test('clock-ahead cutoff is rejected before it can omit a near-start lock',async()=>{const f=await fixture();f.add('activityOccurrences',11,{activity_id:1,schedule_id:5,started_at:Date.now()+10000,status:'pending',activity_log_id:null});f.store.values.set('userMirrors/child/planLocks/occurrence_11',{operationId:'d'.repeat(32)});const p=f.plan('setActivityScheduleEnabled');p.values.effectiveFrom=Date.now()+20000;p.expected=versions(scopeRows(f.rows,p));await assert.rejects(f.plans.submit('parent',p));});
