'use strict';
const {FamilyError}=require('./security.cjs');
const {operationFor}=require('./plan_operations.cjs');
const fail=code=>{throw new FamilyError(code);};
const entity=(kind,id)=>({kind,id:String(id)});
const related=(relation,id,cutoff)=>({relation,id,cutoff});
function* occurrenceDependencies(payload){
  yield entity('activities',payload.activity_id);
  if(payload.schedule_id)yield entity('activitySchedules',payload.schedule_id);
  if(payload.activity_log_id)yield entity('activityLogs',payload.activity_log_id);
}
// Both Firestore loading and in-memory revision selection traverse this graph.
function* scopeRequests(plan){
  const op=operationFor(plan.type);
  switch(op.scope){
    case 'definition':
      if(op.target)yield entity(op.target,plan.targetId);
      return;
    case 'activityReference':
      if(plan.values.activityId!==null)yield entity('activities',plan.values.activityId);
      return;
    case 'occurrence':{
      const p=yield entity('activityOccurrences',plan.targetId);
      yield* occurrenceDependencies(p);
      return;
    }
    case 'schedule':{
      const p=yield entity('activitySchedules',plan.targetId);
      yield entity('activities',p.activity_id);
      const rows=yield related('schedule',plan.targetId,plan.values.effectiveFrom);
      for(const row of rows)if(row.payload.activity_log_id)yield entity('activityLogs',row.payload.activity_log_id);
      return;
    }
    case 'meal':{
      if(op.target){
        yield entity('meals',plan.targetId);
        const rows=yield related('meal',plan.targetId);
        for(const row of rows)if(row.kind==='mealIngredients'){
          yield entity('ingredients',row.payload.ingredient_id);
          if(row.payload.portion_id)yield entity('portions',row.payload.portion_id);
        }
      }
      for(const item of plan.values.ingredients)if(item.ingredientId!==null)yield entity('ingredients',item.ingredientId);
      return;
    }
    default:fail('invalid-argument');
  }
}
function matchesRelation(row,request){
  if(row.deleted)return false;
  if(request.relation==='schedule')return row.kind==='activityOccurrences'&&row.payload.schedule_id===request.id&&row.payload.started_at>request.cutoff;
  return ['mealIngredients','mealHistory','mealSnapshots'].includes(row.kind)&&row.payload.meal_id===request.id;
}
function sorted(selected){return [...selected.values()].sort((a,b)=>`${a.kind}/${a.id}`.localeCompare(`${b.kind}/${b.id}`));}
function scopeRows(rows,plan){
  const selected=new Map(),graph=scopeRequests(plan);
  let step=graph.next();
  while(!step.done){
    const request=step.value;
    if(request.relation){
      const found=rows.filter(r=>matchesRelation(r,request));
      for(const row of found)selected.set(`${row.kind}/${row.id}`,row);
      step=graph.next(found);
    }else{
      const row=rows.find(r=>r.kind===request.kind&&r.id===request.id&&!r.deleted);
      if(!row)fail('failed-precondition');
      selected.set(`${row.kind}/${row.id}`,row);
      step=graph.next(row.payload);
    }
  }
  return sorted(selected);
}
async function loadRows(tx,entities,plan){
  const selected=new Map(),graph=scopeRequests(plan);
  let step=graph.next();
  while(!step.done){
    const request=step.value;
    if(request.relation){
      let query=request.relation==='schedule'
        ?entities.where('payload.schedule_id','==',request.id).where('payload.started_at','>',request.cutoff)
        :entities.where('payload.meal_id','==',request.id);
      const snapshot=await tx.get(query.limit(251));
      if(snapshot.docs.length>250)fail('resource-exhausted');
      const found=snapshot.docs.map(doc=>doc.data()).filter(r=>matchesRelation(r,request));
      for(const row of found)selected.set(`${row.kind}/${row.id}`,row);
      step=graph.next(found);
    }else{
      const row=(await tx.get(entities.doc(`${request.kind}_${request.id}`))).data();
      if(!row||row.deleted)fail('failed-precondition');
      selected.set(`${row.kind}/${row.id}`,row);
      step=graph.next(row.payload);
    }
  }
  return sorted(selected);
}
const versions=rows=>rows.map(({kind,id,revision})=>({kind,id,revision})).sort((a,b)=>`${a.kind}/${a.id}`.localeCompare(`${b.kind}/${b.id}`));
module.exports={scopeRows,loadRows,versions};
