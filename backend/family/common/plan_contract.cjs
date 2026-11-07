'use strict';
const {FamilyError,exact}=require('./security.cjs');
const {operationFor}=require('./plan_operations.cjs');
const {scopeRows,versions}=require('./plan_scope.cjs');
const fail=()=>{throw new FamilyError('invalid-argument');};
const positive=value=>Number.isSafeInteger(value)&&value>0;
function validatePlan(data,checkTime=true){
  exact(data,['id','sourceId','type','targetId','expected','values']);
  if(typeof data.id!=='string'||!/^[a-f0-9]{32}$/.test(data.id)||typeof data.sourceId!=='string'||!/^[a-f0-9]{32}$/.test(data.sourceId))fail();
  const operation=operationFor(data.type);
  if(operation.target?!positive(data.targetId):data.targetId!==null)fail();
  if(!Array.isArray(data.expected)||data.expected.length>250||Buffer.byteLength(JSON.stringify(data))>60000)fail();
  for(const row of data.expected){exact(row,['kind','id','revision']);if(typeof row.kind!=='string'||typeof row.id!=='string'||!positive(row.revision))fail();}
  if(!data.values||typeof data.values!=='object'||Array.isArray(data.values))fail();
  operation.validate(data.values,checkTime);
}
module.exports={validatePlan,scopeRows,versions};
