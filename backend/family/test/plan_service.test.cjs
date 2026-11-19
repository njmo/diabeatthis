'use strict';
process.env.PAIRING_HMAC_KEY = 'pairing-code-test-secret';
const test=require('node:test');const assert=require('node:assert/strict');
const {PlanMemoryStore}=require('./plan_memory_store.cjs');
const {MemoryStore}=require('./memory_store.cjs');
const {createFamilyService}=require('../common/family_service.cjs');
const {createMirrorService}=require('../common/mirror_service.cjs');
const {createPlanService}=require('../common/plan_service.cjs');
const {versions}=require('../common/plan_contract.cjs');
const mirrorContract = require('../common/mirror_contract.json');
const sourceId='a'.repeat(32);
async function fixture(store = new PlanMemoryStore()){
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

test('ingredient search is scoped to the paired child and follows mirror writes', async () => {
  const {store} = await fixture(new MemoryStore());
  const mirror = createMirrorService({store});
  const payload = Object.fromEntries(mirrorContract.ingredients.columns.map(column => [column, null]));
  const record = {
    kind: 'ingredients', id: '2', revision: 1, deleted: false,
    payload: {...payload, id: 2, name: 'Fantasia Łąkowa', brand: 'Danone'},
  };
  await mirror.publish('child', {sourceId, records: [record]});
  const matches = await mirror.searchIngredients('parent', {query: 'LAK fana'});
  assert.deepEqual(matches.records.map(row => row.payload.name), []);
  const results = await mirror.searchIngredients('parent', {query: 'LAK fant'});
  assert.equal(results.ownerUid, 'child');
  assert.deepEqual(results.records.map(row => row.payload.name), ['Fantasia Łąkowa']);
  assert.equal((await mirror.searchIngredients('parent', {query: 'dan'})).records.length, 1);
  store.values.set('userMirrors/child/entities/ingredientPortions_2_1', {
    kind: 'ingredientPortions', payload: {ingredient_id: 2, portion_id: 1, grams_per_portion: 25},
  });
  store.values.set('userMirrors/child/entities/portions_1', {payload: {name: 'sztuka'}});
  assert.deepEqual(await mirror.searchIngredients('parent', {ingredientId: 2}), {ownerUid: 'child', gramsPerPiece: 25});
  await mirror.publish('child', {sourceId, records: [{
    kind: 'quickLowTreatmentItems', id: '1', revision: 1, deleted: false,
    payload: {id: 1, name: 'Fantasia', ingredient_id: 2, portion_id: 1, amount: 2, sort_order: 1},
  }]});
  const quick = await mirror.searchIngredients('parent', {quickFoods: true});
  assert.deepEqual(quick.foods.map(({name, amount, gramsPerUnit}) => ({name, amount, gramsPerUnit})), [
    {name: 'Fantasia', amount: 2, gramsPerUnit: 25},
  ]);
  await assert.rejects(mirror.searchIngredients('parent', {query: 'fant', childUid: 'other'}), error => error.code === 'invalid-argument');
  await assert.rejects(mirror.searchIngredients('stranger', {query: 'fant'}), error => error.code === 'permission-denied');
  await assert.rejects(mirror.searchIngredients('child', {query: 'fant'}), error => error.code === 'permission-denied');
  await mirror.publish('child', {sourceId, records: [{...record, revision: 2, deleted: true, payload: null}]});
  assert.deepEqual((await mirror.searchIngredients('parent', {query: 'fant'})).records, []);
});
test('ingredient search keeps scanning after a full non-matching page', async () => {
  const {store} = await fixture(new MemoryStore());
  const mirror = createMirrorService({store});
  for (let id = 100; id < 500; id++) {
    store.values.set(`userMirrors/child/entities/ingredients_${id}`, {
      kind: 'ingredients', id: String(id), deleted: false,
      ingredientSearchPrefixes: ['fantasia'],
      payload: {id, name: id === 145 ? 'Fantasia maltesers' : 'Fantasia wanilia'},
    });
  }
  const result = await mirror.searchIngredients('parent', {query: 'fantasia malt'});
  assert.deepEqual(result.records.map(row => row.id), ['145']);
  store.values.set('userMirrors/child/entities/ingredients_500', {
    kind: 'ingredients', id: '500', deleted: false,
    ingredientSearchPrefixes: ['fantasia'], payload: {id: 500, name: 'Fantasia wanilia'},
  });
  await assert.rejects(mirror.searchIngredients('parent', {query: 'fantasia malt'}), {code: 'resource-exhausted'});
});

test('shortcut editor loads only versioned rows needed for the selected child', async () => {
  const {store, plans} = await fixture(new MemoryStore());
  const mirror = createMirrorService({store});
  store.values.get('userMirrors/child').activityCommandsVersion = 6;
  for (const [kind, id, payload] of [
    ['quickLowTreatmentItems', '5', {id: 5, ingredient_id: 1, portion_id: 2}],
    ['ingredientPortions', '1_2', {ingredient_id: 1, portion_id: 2}],
    ['portions', '2', {id: 2, name: 'piece'}],
  ]) {
    store.values.set(`userMirrors/child/entities/${kind}_${id}`, {
      kind, id, payload, revision: 3, deleted: false,
    });
  }
  const snapshot = await mirror.searchIngredients('parent', {quickFoodsEditor: true});
  assert.equal(snapshot.sourceId, sourceId);
  assert.equal(snapshot.ownerUid, 'child');
  assert.deepEqual(snapshot.records.map(row => [row.kind, row.revision]).sort(), [
    ['ingredientPortions', 3], ['ingredients', 1], ['portions', 3], ['quickLowTreatmentItems', 3],
  ]);
  const detail = await mirror.searchIngredients('parent', {ingredientDetailsId: 1});
  assert.deepEqual(detail.records.map(row => row.kind).sort(), ['ingredientPortions', 'ingredients', 'portions']);
  await assert.rejects(mirror.searchIngredients('child', {quickFoodsEditor: true}), {code: 'permission-denied'});
  const proposal = {
    id: 'd'.repeat(32), sourceId, type: 'replaceQuickTreatmentItems', targetId: null,
    expected: versions(snapshot.records),
    values: {items: [{id: 5, name: 'Bread', ingredientId: 1, portionId: 2, amount: 1}]},
  };
  store.values.get('userMirrors/child/entities/ingredientPortions_1_2').revision++;
  await assert.rejects(plans.submit('parent', proposal), {code: 'failed-precondition'});
  proposal.expected = versions((await mirror.searchIngredients('parent', {quickFoodsEditor: true})).records);
  assert.equal((await plans.submit('parent', proposal)).status, 'pending');
});
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

test('shared shortcut list uses the family plan lock and accepts an aggregate ACK', async () => {
  const {store, plans} = await fixture();
  const mirror = createMirrorService({store});
  const proposal = {id: 'd'.repeat(32), sourceId, type: 'replaceQuickTreatmentItems', targetId: null, expected: [], values: {items: []}};
  await mirror.register('child', {sourceId, activityCommandsVersion: 5});
  await assert.rejects(plans.submit('parent', proposal), error => error.code === 'failed-precondition');
  await mirror.register('child', {sourceId, activityCommandsVersion: 6});
  assert.equal((await plans.submit('parent', proposal)).status, 'pending');
  await assert.rejects(plans.submit('parent2', {...proposal, id: 'e'.repeat(32)}), error => error.code === 'failed-precondition');
  assert.equal((await plans.fetch('child', {activityCommandsVersion: 5})).plans.length, 0);
  const claim = await plans.claim('child', {id: proposal.id, sourceId, activityCommandsVersion: 6});
  const result = await plans.acknowledge('child', {id: proposal.id, sourceId, claimToken: claim.claimToken, outcome: 'applied', reason: null, resultId: null});
  assert.equal(result.status, 'applied');
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

test('untimed proposals are only delivered to a child with protocol 5', async () => {
  const {plans, proposal, store} = await fixture();
  const mirror = createMirrorService({store});
  const plannedDay = new Date().toISOString().slice(0, 10);
  const untimed = {
    ...proposal,
    values: {...proposal.values, plannedAt: null, plannedDay},
  };

  await mirror.register('child', {sourceId, activityCommandsVersion: 4});
  await assert.rejects(plans.submit('parent', untimed), error => error.code === 'failed-precondition');
  await mirror.register('child', {sourceId, activityCommandsVersion: 5});
  assert.equal((await plans.submit('parent', untimed)).status, 'pending');
  assert.equal((await plans.fetch('child', {activityCommandsVersion: 4})).plans.length, 0);
  await assert.rejects(
    plans.claim('child', {id: untimed.id, sourceId, activityCommandsVersion: 4}),
    error => error.code === 'failed-precondition',
  );
  assert.equal((await plans.fetch('child', {activityCommandsVersion: 5})).plans.length, 1);
  assert.ok((await plans.claim('child', {id: untimed.id, sourceId, activityCommandsVersion: 5})).claimToken);
});
