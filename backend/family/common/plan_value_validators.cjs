'use strict';
const {FamilyError,exact}=require('./security.cjs');
const {validateActivitySchedule}=require('./activity_schedule_contract.cjs');
const fail=()=>{throw new FamilyError('invalid-argument');};
const positive=value=>Number.isSafeInteger(value)&&value>0;
const future=(value,checkTime)=>positive(value)&&(!checkTime||value>Date.now()&&value<Date.now()+366*86400000);
function activityReference(v){
  if(positive(v.activityId)&&!Object.hasOwn(v,'activity'))return;
  if(v.activityId!==null||!Object.hasOwn(v,'activity'))fail();
  const a=v.activity;exact(a,['name','percentagePre','percentagePost','durationMinutes']);
  if(typeof a.name!=='string'||a.name.trim().length<2||a.name.trim().length>30||!positive(a.percentagePre)||a.percentagePre>99||!positive(a.percentagePost)||a.percentagePost>99||(a.durationMinutes!==null&&(!positive(a.durationMinutes)||a.durationMinutes>1440)))fail();
}
function inlineSchedule(v){
  if(!Object.hasOwn(v,'schedule'))return;
  if(v.activityId!==null||!Object.hasOwn(v,'activity'))fail();
  validateActivitySchedule(v.schedule);
}
function referenceKeys(v){return ['activityId',...(Object.hasOwn(v,'activity')?['activity']:[]),...(Object.hasOwn(v,'schedule')?['schedule']:[])];}
function meal(v,checkTime){
  const untimed=Object.hasOwn(v,'plannedDay');
  exact(v,['name','category','plannedAt','notes','ingredients',...(untimed?['plannedDay']:[])]);
  const day=untimed&&typeof v.plannedDay==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(v.plannedDay)
    ? Date.parse(v.plannedDay+'T00:00:00Z') : NaN;
  const validTiming=untimed
    ? v.plannedAt===null&&Number.isFinite(day)&&new Date(day).toISOString().slice(0,10)===v.plannedDay&&
      (!checkTime||(day<=Date.now()+86400000&&day+2*86400000>Date.now()))
    : future(v.plannedAt,checkTime);
  if(!['breakfast','secondBreakfast','lunch','snack','afternoonSnack','dinner'].includes(v.category))fail();
  if(typeof v.name!=='string'||!v.name.trim()||v.name.length>120||typeof v.notes!=='string'||v.notes.length>2000||!validTiming||!Array.isArray(v.ingredients)||v.ingredients.length<1||v.ingredients.length>30)fail();
  for(const item of v.ingredients){
    exact(item,['ingredientId','catalogId','catalogRevision','grams']);
    const local=positive(item.ingredientId)&&item.catalogId===null&&item.catalogRevision===null;
    const catalog=item.ingredientId===null&&typeof item.catalogId==='string'&&/^usda_[1-9][0-9]*$/.test(item.catalogId)&&item.catalogId.length<=80&&typeof item.catalogRevision==='string'&&/^[a-f0-9]{64}$/.test(item.catalogRevision);
    if((!local&&!catalog)||typeof item.grams!=='number'||!Number.isFinite(item.grams)||item.grams<=0||item.grams>10000)fail();
  }
  if(new Set(v.ingredients.map(r=>r.ingredientId===null?'catalog:'+r.catalogId:'local:'+r.ingredientId)).size!==v.ingredients.length)fail();
}
function definition(v){exact(v,['activity','schedule']);activityReference({activityId:null,activity:v.activity});if(v.schedule!==null)validateActivitySchedule(v.schedule);}
function schedule(v){exact(v,['schedule']);validateActivitySchedule(v.schedule);}
function activation(v,checkTime){exact(v,['enabled','effectiveFrom']);if(typeof v.enabled!=='boolean'||!positive(v.effectiveFrom)||(checkTime&&(v.effectiveFrom<Date.now()-300000||v.effectiveFrom>Date.now())))fail();}
function plannedActivity(v,checkTime){exact(v,[...referenceKeys(v),'startedAt','durationMinutes']);activityReference(v);inlineSchedule(v);if(!future(v.startedAt,checkTime)||!positive(v.durationMinutes)||v.durationMinutes>1440)fail();}
function startedActivity(v,checkTime){exact(v,[...referenceKeys(v),'startedAt']);activityReference(v);inlineSchedule(v);if(!positive(v.startedAt)||(checkTime&&(v.startedAt>Date.now()+30000||v.startedAt<Date.now()-300000)))fail();}
function loggedActivity(v,checkTime){exact(v,[...referenceKeys(v),'startedAt','endedAt']);activityReference(v);inlineSchedule(v);if(!positive(v.startedAt)||!positive(v.endedAt)||v.endedAt<=v.startedAt||v.endedAt-v.startedAt>1440*60000||(checkTime&&v.endedAt>Date.now()))fail();}
function movedActivity(v,checkTime){exact(v,['startedAt']);if(!future(v.startedAt,checkTime))fail();}
const empty=v=>exact(v,[]);
module.exports={meal,definition,schedule,activation,plannedActivity,startedActivity,loggedActivity,movedActivity,empty};
