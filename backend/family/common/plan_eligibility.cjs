'use strict';
const {FamilyError}=require('./security.cjs');
const {operationFor,recordLock}=require('./plan_operations.cjs');
const fail=()=>{throw new FamilyError('failed-precondition');};
const find=(rows,kind,id)=>rows.find(r=>r.kind===kind&&r.id===String(id)&&!r.deleted)?.payload;
function monitored(guards,kind,id){return guards.some(r=>r.kind==='workflowLocks'&&!r.deleted&&r.payload.active===1&&r.payload.kind===kind&&r.payload.entity_id===id&&!(kind==='activity'&&r.payload.phase==='planned'));}
function preparing(occurrence,now){return occurrence.target_requested_at!=null&&occurrence.started_at<=now+90*60000;}
function assertOccurrenceAvailable(occurrence,rows,guards,now){
  const log=find(rows,'activityLogs',occurrence.activity_log_id);
  if(log&&(log.started_at<=now||log.ended_at!=null))fail();
  if(preparing(occurrence,now)||monitored(guards,'activity',occurrence.activity_log_id))fail();
}
const policies={
  none(){},
  plannedMeal({plan,rows,guards}){
    const meal=find(rows,'meals',plan.targetId);
    if(!meal||meal.status!=='planned'||meal.purpose!=='meal'||monitored(guards,'meal',plan.targetId))fail();
  },
  pendingOccurrence:context=>futureOccurrence(context,['pending']),
  futureOccurrence:context=>futureOccurrence(context,['pending','planned']),
  scheduleActivation({plan,rows,guards,now}){
    if(plan.values.enabled)return;
    for(const row of rows.filter(r=>r.kind==='activityOccurrences'&&r.payload.started_at>now))assertOccurrenceAvailable(row.payload,rows,guards,now);
  },
};
function futureOccurrence(context,statuses){
  const {plan,rows,guards,now}=context;
  const occurrence=find(rows,'activityOccurrences',plan.targetId);
  if(!occurrence||occurrence.started_at<=now||!statuses.includes(occurrence.status))fail();
  assertOccurrenceAvailable(occurrence,rows,guards,now);
}
function assertEligible(plan,rows,guards,now=Date.now()){
  policies[operationFor(plan.type).eligibility]({plan,rows,guards,now});
}
function relatedLocks(plan,rows){
  const scope=operationFor(plan.type).scope;
  if(scope==='schedule')return rows.filter(r=>r.kind==='activityOccurrences').map(r=>recordLock('activityOccurrences',r.id));
  if(scope==='occurrence'){
    const occurrence=find(rows,'activityOccurrences',plan.targetId);
    return occurrence?.schedule_id?[recordLock('activitySchedules',occurrence.schedule_id)]:[];
  }
  return [];
}
module.exports={assertEligible,relatedLocks};
