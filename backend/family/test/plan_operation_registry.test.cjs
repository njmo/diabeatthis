'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {operations,operationFor,requiredProtocol,supportsPlan,primaryLock,resultLock,canonicalReferences,validateProtocol}=require('../common/plan_operations.cjs');
const {validatePlan}=require('../common/plan_contract.cjs');
const {scopeRows,loadRows}=require('../common/plan_scope.cjs');
const now=Date.now(),future=now+3600000;
const activity={name:'Training',percentagePre:20,percentagePost:30,durationMinutes:43};
const schedule={weekdays:[1],startMinute:1020,durationMinutes:43,confirmationMode:'before',previousDayMinute:1140,validFrom:now,validUntil:null};
const meal={name:'Lunch',category:'lunch',plannedAt:future,notes:'',ingredients:[{ingredientId:6,catalogId:null,catalogRevision:null,grams:100}]};
const cases={
 createMeal:[null,meal,0,'new_', 'meal', 'meals'],
 updateMeal:[5,meal,0,'meal_', 'meal','meals'],
 planActivity:[null,{activityId:1,startedAt:future,durationMinutes:43},0,'new_','occurrence','activityOccurrences'],
 startActivity:[null,{activityId:1,startedAt:now},1,'activity_start','activityLog','activityLogs'],
 logActivity:[null,{activityId:1,startedAt:now-3600000,endedAt:now-60000},1,'new_','activityLog','activityLogs'],
 confirmActivity:[3,{},0,'occurrence_','occurrence','activityOccurrences'],
 moveActivity:[3,{startedAt:future+3600000},0,'occurrence_','occurrence','activityOccurrences'],
 skipActivity:[3,{},4,'occurrence_','occurrence','activityOccurrences'],
 createActivity:[null,{activity,schedule},3,'new_','activity','activities'],
 updateActivity:[1,{activity,schedule:null},3,'activity_','activity','activities'],
 createActivitySchedule:[1,{schedule},3,'activity_','schedule','activitySchedules'],
 setActivityScheduleEnabled:[2,{enabled:false,effectiveFrom:now-60000},4,'schedule_','schedule','activitySchedules'],
};
const row=(kind,id,payload)=>({kind,id:String(id),revision:1,deleted:false,payload:{id,...payload}});
const rows=[row('activities',1,activity),row('activitySchedules',2,{activity_id:1}),row('activityOccurrences',3,{activity_id:1,schedule_id:2,activity_log_id:4,started_at:future,status:'planned'}),row('activityLogs',4,{activity_id:1,started_at:future,ended_at:null}),row('meals',5,{status:'planned',purpose:'meal'}),row('ingredients',6,{name:'Bread'}),row('portions',7,{ingredient_id:6}),row('mealIngredients',8,{meal_id:5,ingredient_id:6,portion_id:7}),row('mealHistory',9,{meal_id:5}),row('mealSnapshots',10,{meal_id:5}),row('activityOccurrences',11,{activity_id:1,schedule_id:2,activity_log_id:12,started_at:now-86400000,status:'recorded'}),row('activityLogs',12,{activity_id:1,started_at:now-86400000,ended_at:now-86000000})];
function scopeStore(rows){
 const collection=(filters=[],limit=null)=>({filters,limitValue:limit,doc:id=>({id}),where:(field,operator,value)=>collection([...filters,{field,operator,value}],limit),limit:value=>collection(filters,value)});
 const entities=collection();
 const tx={get:async request=>{
  if(request.id)return {data:()=>rows.find(r=>`${r.kind}_${r.id}`===request.id)};
  const field=(row,key)=>key.split('.').reduce((v,k)=>v?.[k],row);
  return {docs:rows.filter(r=>request.filters.every(f=>f.operator==='=='?field(r,f.field)===f.value:field(r,f.field)>f.value)).slice(0,request.limitValue??rows.length).map(r=>({data:()=>r}))};
 }};
 return {tx,entities};
}
for(const [type,[targetId,values,protocol,lockPrefix,resultPrefix,resultKind]] of Object.entries(cases)){
 test(`${type}: one contract drives protocol, locks, payload and both scope readers`,async()=>{
  const plan={id:'a'.repeat(32),sourceId:'b'.repeat(32),type,targetId,expected:[],values};
  assert.doesNotThrow(()=>validatePlan(plan));assert.equal(requiredProtocol(plan),protocol);
  for(let version=0;version<=4;version++)assert.equal(supportsPlan(plan,version),version>=protocol);
  const key=primaryLock(plan);assert.equal(key,lockPrefix==='activity_start'?lockPrefix:lockPrefix+(lockPrefix==='new_'?plan.id:targetId));
  assert.equal(resultLock(plan,99),`${resultPrefix}_99`);assert.equal(resultLock(plan,null),null);
  assert.deepEqual(canonicalReferences(plan,99)[0],{kind:resultKind,id:99});
  const store=scopeStore(rows);assert.deepEqual(await loadRows(store.tx,store.entities,plan),scopeRows(rows,plan));
  assert.throws(()=>validatePlan({...plan,targetId:targetId===null?1:null}));
 });
}
test('registry is complete, immutable and denies unknown/prototype operations',()=>{
 assert.deepEqual(Object.keys(operations).sort(),Object.keys(cases).sort());
 for(const op of Object.values(operations))assert.equal(Object.isFrozen(op),true);
 for(const type of ['constructor','toString','__proto__','unexpected'])assert.throws(()=>operationFor(type));
 for(const version of [-1,0,5,'4',null])assert.throws(()=>validateProtocol({activityCommandsVersion:version}));
 assert.doesNotThrow(()=>validateProtocol({}));
});
test('inline definition and recurrence consistently increase protocol in every reader',()=>{
 for(const type of ['planActivity','startActivity','logActivity']){
  const values={...cases[type][1],activityId:null,activity};const plan={type,values};
  assert.equal(requiredProtocol(plan),2);assert.equal(supportsPlan(plan,1),false);
  plan.values={...values,schedule};assert.equal(requiredProtocol(plan),3);assert.equal(supportsPlan(plan,2),false);
 }
});
test('scope graph excludes old sessions and rejects missing/deleted dependencies',async()=>{
 const plan={type:'setActivityScheduleEnabled',targetId:2,values:cases.setActivityScheduleEnabled[1]};
 assert.deepEqual(scopeRows(rows,plan).map(r=>`${r.kind}/${r.id}`).sort(),['activities/1','activityLogs/4','activityOccurrences/3','activitySchedules/2'].sort());
 for(const missing of ['activities','activitySchedules','activityLogs']){
  const source=rows.map(r=>r.kind===missing?{...r,deleted:true}:r);
  assert.throws(()=>scopeRows(source,plan));const store=scopeStore(source);await assert.rejects(loadRows(store.tx,store.entities,plan));
 }
});
