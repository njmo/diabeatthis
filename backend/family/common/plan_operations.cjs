'use strict';
const {FamilyError}=require('./security.cjs');
const values=require('./plan_value_validators.cjs');

// The operation contract is the only source of protocol, scope and record kinds.
const operations=Object.freeze({
  createMeal:{target:null,result:'meals',scope:'meal',protocol:0,validate:values.meal,eligibility:'none'},
  updateMeal:{target:'meals',result:'meals',scope:'meal',protocol:0,validate:values.meal,eligibility:'plannedMeal'},
  planActivity:{target:null,result:'activityOccurrences',scope:'activityReference',protocol:0,validate:values.plannedActivity,eligibility:'none'},
  startActivity:{target:null,result:'activityLogs',scope:'activityReference',protocol:1,validate:values.startedActivity,eligibility:'none',globalLock:'activity_start'},
  logActivity:{target:null,result:'activityLogs',scope:'activityReference',protocol:1,validate:values.loggedActivity,eligibility:'none'},
  confirmActivity:{target:'activityOccurrences',result:'activityOccurrences',scope:'occurrence',protocol:0,validate:values.empty,eligibility:'pendingOccurrence'},
  moveActivity:{target:'activityOccurrences',result:'activityOccurrences',scope:'occurrence',protocol:0,validate:values.movedActivity,eligibility:'futureOccurrence'},
  skipActivity:{target:'activityOccurrences',result:'activityOccurrences',scope:'occurrence',protocol:4,validate:values.empty,eligibility:'futureOccurrence'},
  createActivity:{target:null,result:'activities',scope:'definition',protocol:3,validate:values.definition,eligibility:'none'},
  updateActivity:{target:'activities',result:'activities',scope:'definition',protocol:3,validate:values.definition,eligibility:'none'},
  createActivitySchedule:{target:'activities',result:'activitySchedules',scope:'definition',protocol:3,validate:values.schedule,eligibility:'none'},
  setActivityScheduleEnabled:{target:'activitySchedules',result:'activitySchedules',scope:'schedule',protocol:4,validate:values.activation,eligibility:'scheduleActivation'},
});
for(const operation of Object.values(operations))Object.freeze(operation);
const prefixes=Object.freeze({meals:'meal',activities:'activity',activityLogs:'activityLog',activityOccurrences:'occurrence',activitySchedules:'schedule'});
const maximumProtocol=5;
function operationFor(type){
  if(typeof type!=='string'||!Object.hasOwn(operations,type))throw new FamilyError('invalid-argument');
  return operations[type];
}
function requiredProtocol(plan){
  const operation=operationFor(plan.type);
  const untimedMeal=operation.scope==='meal'&&Object.hasOwn(plan.values,'plannedDay');
  return Math.max(operation.protocol,plan.values.activity?2:0,plan.values.schedule?3:0,untimedMeal?5:0);
}
function supportsPlan(plan,version=0){return Number.isInteger(version)&&version>=requiredProtocol(plan);}
function validateProtocol(data){
  if(Object.hasOwn(data,'activityCommandsVersion')&&(!Number.isInteger(data.activityCommandsVersion)||data.activityCommandsVersion<1||data.activityCommandsVersion>maximumProtocol))throw new FamilyError('invalid-argument');
}
function recordLock(kind,id){return `${prefixes[kind]}_${id}`;}
function primaryLock(plan){const op=operationFor(plan.type);return op.globalLock??(op.target?recordLock(op.target,plan.targetId):`new_${plan.id}`);}
function resultLock(plan,id){return id===null?null:recordLock(operationFor(plan.type).result,id);}
function canonicalReferences(plan,resultId){
  const op=operationFor(plan.type);
  return [{kind:op.result,id:resultId},...(op.target?[{kind:op.target,id:plan.targetId}]:[])].filter(r=>r.id!==null);
}
module.exports={operations,operationFor,requiredProtocol,supportsPlan,validateProtocol,primaryLock,resultLock,recordLock,canonicalReferences,maximumProtocol};
