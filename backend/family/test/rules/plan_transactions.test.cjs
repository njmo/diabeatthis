'use strict';
process.env.PAIRING_HMAC_KEY = 'pairing-code-test-secret';
const test=require('node:test');const assert=require('node:assert/strict');
const {initializeApp,deleteApp}=require('firebase-admin/app');const {getFirestore}=require('firebase-admin/firestore');
const {createFamilyService}=require('../../common/family_service.cjs');const {createMirrorService}=require('../../common/mirror_service.cjs');const {createPlanService}=require('../../common/plan_service.cjs');
const contract=require('../../common/mirror_contract.json');
test('real Firestore serializes parent locks, child claim and canonical ACK',async()=>{
  const app=initializeApp({projectId:'demo-diabeatthis-family'},'plan-transactions');const store=getFirestore(app);
  const child='plans-child',parent='plans-parent',parent2='plans-parent2',sourceId='d'.repeat(32);
  const family=createFamilyService({store,auth:{getUser:async uid=>({emailVerified:true,providerData:[{providerId:'google.com',displayName:uid}]})}});
  const plans=createPlanService({store}),mirror=createMirrorService({store});
  const row=(kind,id,values)=>({kind,id:String(id),revision:1,deleted:false,payload:Object.fromEntries(contract[kind].columns.map(key=>[key,values[key]??null]))});
  try{
    for(const [user,approver]of[[parent,child],[parent2,parent]]){const invite=await family.createInvite(child,{});await family.requestJoin(user,{inviteId:invite.id,token:invite.token});await family.decide(approver,{inviteId:invite.id,approve:true});}
    await mirror.register(child,{sourceId});
    const records=[row('ingredients',1,{id:1,name:'Bread',carbs_per_100g:40}),row('meals',1,{id:1,name:'Lunch',status:'planned',purpose:'meal',planned_at:Date.now()+7200000})];
    await mirror.publish(child,{sourceId,records});
    const proposal={id:'a'.repeat(32),sourceId,type:'updateMeal',targetId:1,expected:records.map(({kind,id,revision})=>({kind,id,revision})),values:{name:'Lunch',category:'lunch',plannedAt:Date.now()+7200000,notes:'',ingredients:[{ingredientId:1,catalogId:null,catalogRevision:null,grams:100}]}};
    const results=await Promise.allSettled([plans.submit(parent,proposal),plans.submit(parent2,{...proposal,id:'b'.repeat(32)})]);
    assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
    const pending=(await plans.fetch(child,{})).plans[0];
    const claim=await plans.claim(child,{id:pending.id,sourceId});assert.equal(claim.authorActive,true);
    const meal={...records[1],revision:2,payload:{...records[1].payload,name:'Child version'}};
    await mirror.publish(child,{sourceId,records:[meal]});
    await plans.acknowledge(child,{id:pending.id,sourceId,claimToken:claim.claimToken,outcome:'rejected',reason:'conflict',resultId:null});
    const received=(await plans.fetch(parent,{})).plans[0];assert.equal(received.status,'rejected');assert.equal(received.canonical.find(r=>r.kind==='meals').payload.name,'Child version');assert.equal(received.claimToken,undefined);
    await assert.rejects(plans.claim(parent,{id:pending.id,sourceId}));await assert.rejects(plans.fetch('plans-stranger',{}));
  }finally{await store.terminate();await deleteApp(app);}
});

test('empty child can receive a catalog meal with prepared and final acknowledgement',async()=>{
  const app=initializeApp({projectId:'demo-diabeatthis-family'},'plan-empty-child');const store=getFirestore(app);
  const child='empty-plan-child',parent='empty-plan-parent',sourceId='e'.repeat(32);
  const family=createFamilyService({store,auth:{getUser:async uid=>({emailVerified:true,providerData:[{providerId:'google.com',displayName:uid}]})}});
  const plans=createPlanService({store}),mirror=createMirrorService({store});
  try{
    const invite=await family.createInvite(child,{});await family.requestJoin(parent,{inviteId:invite.id,token:invite.token});await family.decide(child,{inviteId:invite.id,approve:true});
    await mirror.register(child,{sourceId});
    await store.doc('common/ingredients/items/usda_99999991').set({id:'usda_99999991',name:'Apple'});
    const proposal={id:'f'.repeat(32),sourceId,type:'createMeal',targetId:null,expected:[],values:{name:'Snack',category:'snack',plannedAt:Date.now()+3600000,notes:'',ingredients:[{ingredientId:null,catalogId:'usda_99999991',catalogRevision:'a'.repeat(64),grams:150}]}};
    await plans.submit(parent,proposal);const claim=await plans.claim(child,{id:proposal.id,sourceId});
    const ack={id:proposal.id,sourceId,claimToken:claim.claimToken,reason:null,resultId:1};
    assert.equal((await plans.acknowledge(child,{...ack,outcome:'prepared'})).status,'pending');
    const record={kind:'meals',id:'1',revision:1,deleted:false,payload:Object.fromEntries(contract.meals.columns.map(key=>[key,({id:1,name:'Snack',category:'snack',planned_at:proposal.values.plannedAt,status:'planned',purpose:'meal'})[key]??null]))};
    await mirror.publish(child,{sourceId,records:[record]});
    assert.equal((await plans.acknowledge(child,{...ack,outcome:'applied'})).status,'applied');
    assert.equal((await plans.fetch(parent,{})).plans[0].status,'applied');
    assert.equal((await mirror.fetch(parent,{after:0})).records[0].payload.name,'Snack');
  }finally{await store.terminate();await deleteApp(app);}
});
