'use strict';
process.env.PAIRING_HMAC_KEY = 'pairing-code-test-secret';
const test=require('node:test');const assert=require('node:assert/strict');
const {PlanMemoryStore}=require('./plan_memory_store.cjs');
const {createFamilyService}=require('../common/family_service.cjs');
const {createMirrorService}=require('../common/mirror_service.cjs');
const {createPlanService}=require('../common/plan_service.cjs');
const {versions}=require('../common/plan_contract.cjs');
const sourceId='a'.repeat(32);
async function fixture(){
  const store=new PlanMemoryStore();
  const family=createFamilyService({store,auth:{getUser:async uid=>({emailVerified:true,providerData:[{providerId:'google.com',displayName:uid}]})}});
  let invite=await family.createInvite('child',{});await family.requestJoin('parent',{inviteId:invite.id,token:invite.token});await family.decide('child',{inviteId:invite.id,approve:true});
  invite=await family.createInvite('child',{});await family.requestJoin('parent2',{inviteId:invite.id,token:invite.token});await family.decide('parent',{inviteId:invite.id,approve:true});
  await createMirrorService({store}).register('child',{sourceId});
  const ingredients={kind:'ingredients',id:'1',revision:1,deleted:false,payload:{id:1,name:'Bread',carbs_per_100g:40}};
  const meal={kind:'meals',id:'1',revision:1,deleted:false,payload:{id:1,name:'Lunch',status:'planned',purpose:'meal',planned_at:Date.now()+3600000}};
  for(const row of [ingredients,meal])store.values.set(`userMirrors/child/entities/${row.kind}_${row.id}`,row);
  const proposal={id:'b'.repeat(32),sourceId,type:'updateMeal',targetId:1,expected:versions([ingredients,meal]),values:{name:'Lunch',category:'lunch',plannedAt:Date.now()+3600000,notes:'',ingredients:[{ingredientId:1,catalogId:null,catalogRevision:null,grams:100}]}};
  return {store,family,plans:createPlanService({store}),proposal};
}
test('paired caregivers submit, per-record lock blocks other parent until child ACK',async()=>{
  const {plans,proposal}=await fixture();
  await assert.rejects(plans.submit('child',proposal));await assert.rejects(plans.submit('stranger',proposal));
  assert.equal((await plans.submit('parent',proposal)).status,'pending');
  assert.equal((await plans.submit('parent',proposal)).status,'pending');
  await assert.rejects(plans.submit('parent2',{...proposal,id:'c'.repeat(32)}));
  const claim=await plans.claim('child',{id:proposal.id,sourceId});assert.equal(claim.authorActive,true);
  const renewed=await plans.claim('child',{id:proposal.id,sourceId});assert.equal(renewed.claimToken,claim.claimToken);
  await assert.rejects(plans.acknowledge('parent',{id:proposal.id,sourceId,claimToken:claim.claimToken,outcome:'applied',reason:null,resultId:1}));
  await plans.acknowledge('child',{id:proposal.id,sourceId,claimToken:claim.claimToken,outcome:'rejected',reason:'conflict',resultId:null});
  assert.equal((await plans.submit('parent2',{...proposal,id:'c'.repeat(32)})).status,'pending');
  const response=await plans.fetch('parent',{});assert.equal(response.plans.find(p=>p.id===proposal.id).claimToken,undefined);
});
test('offline version mismatch rejects stale proposal; execution fields cannot be submitted',async()=>{
  const {plans,proposal,store}=await fixture();
  store.values.get('userMirrors/child/entities/ingredients_1').revision=2;
  await assert.rejects(plans.submit('parent',proposal));
  await assert.rejects(plans.submit('parent',{...proposal,values:{...proposal.values,status:'eating'}}));
  await assert.rejects(plans.fetch('stranger',{}));
  await assert.rejects(plans.fetch('parent',{ownerUid:'foreign'}));
});
test('claim rechecks author after fetch; disconnected caregiver cannot execute',async()=>{
  const {plans,proposal,family}=await fixture();await plans.submit('parent',proposal);
  assert.equal((await plans.fetch('child',{})).plans[0].authorActive,true);
  await family.disconnect('parent',{memberId:'self'});
  const claim=await plans.claim('child',{id:proposal.id,sourceId});assert.equal(claim.authorActive,false);
  await assert.rejects(plans.fetch('parent',{}));
});
test('invalid-version attempts consume the submission budget',async()=>{
  const {plans,proposal}=await fixture();
  for(let i=0;i<30;i++)await assert.rejects(plans.submit('parent',{...proposal,expected:[]}));
  await assert.rejects(plans.submit('parent',proposal),e=>e.code==='resource-exhausted');
});

test('retry after planned time returns original operation receipt',async()=>{
  const {plans,proposal}=await fixture();await plans.submit('parent',proposal);
  const original=Date.now;Date.now=()=>proposal.values.plannedAt+1;
  try{assert.equal((await plans.submit('parent',proposal)).status,'pending');}
  finally{Date.now=original;}
});
test('all bounded pending operations are fetched even when the first twenty cannot run',async()=>{
  const {plans,store,proposal}=await fixture();
  for(let i=1;i<=25;i++)store.values.set('userMirrors/child/plans/'+i,{...proposal,id:String(i),status:'pending',authorUid:'parent',createdAt:i});
  assert.equal((await plans.fetch('child',{})).plans.length,25);
});
test('a growing aggregate cannot prevent terminal ACK or keep its lock',async()=>{
  const {plans,store,proposal}=await fixture();await plans.submit('parent',proposal);
  const claim=await plans.claim('child',{id:proposal.id,sourceId});
  for(let id=1;id<=300;id++)store.values.set(`userMirrors/child/entities/mealIngredients_${id}`,{kind:'mealIngredients',id:String(id),revision:2,deleted:false,payload:{id,meal_id:1,ingredient_id:1,notes:'x'.repeat(10000)}});
  await plans.acknowledge('child',{id:proposal.id,sourceId,claimToken:claim.claimToken,outcome:'rejected',reason:'conflict',resultId:null});
  const result=(await plans.fetch('parent',{})).plans[0];assert.equal(result.status,'rejected');assert.equal(result.canonicalTruncated,true);assert.ok(Buffer.byteLength(JSON.stringify(result.canonical))<=65536);
  assert.equal(store.values.get('userMirrors/child').pendingPlans,0);assert.equal(store.values.has('userMirrors/child/planLocks/meal_1'),false);
});
test('new result record is locked before publication and released only after final ACK',async()=>{
  const {plans,store,proposal}=await fixture();
  const create={...proposal,type:'createMeal',targetId:null,expected:proposal.expected.filter(r=>r.kind==='ingredients')};
  await plans.submit('parent',create);const claim=await plans.claim('child',{id:create.id,sourceId});
  await plans.acknowledge('child',{id:create.id,sourceId,claimToken:claim.claimToken,outcome:'prepared',reason:null,resultId:2});
  const meal={kind:'meals',id:'2',revision:1,deleted:false,payload:{id:2,status:'planned',purpose:'meal',name:'New lunch'}};
  store.values.set('userMirrors/child/entities/meals_2',meal);
  const edit={...proposal,id:'f'.repeat(32),targetId:2,expected:[...proposal.expected.filter(r=>r.kind==='ingredients'),{kind:'meals',id:'2',revision:1}]};
  await assert.rejects(plans.submit('parent2',edit));
  await plans.acknowledge('child',{id:create.id,sourceId,claimToken:claim.claimToken,outcome:'applied',reason:null,resultId:2});
  assert.equal((await plans.submit('parent2',edit)).status,'pending');
});
test('published monitoring phase blocks caregiver editing even while meal status is planned',async()=>{
  const {plans,store,proposal}=await fixture();
  store.values.set('userMirrors/child/entities/workflowLocks_1',{kind:'workflowLocks',id:'1',revision:1,deleted:false,payload:{id:1,kind:'meal',entity_id:1,phase:'preparing',active:1}});
  await assert.rejects(plans.submit('parent',proposal));
});
