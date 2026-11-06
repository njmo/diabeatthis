'use strict';
const {FamilyError, exact} = require('./security.cjs');
const fail = () => { throw new FamilyError('invalid-argument'); };
const positive = value => Number.isSafeInteger(value) && value > 0;
const future = (value,checkTime) => positive(value) && (!checkTime || value > Date.now() && value < Date.now() + 366 * 86400000);
function validatePlan(data, checkTime=true) {
  exact(data, ['id', 'sourceId', 'type', 'targetId', 'expected', 'values']);
  if (typeof data.id !== 'string' || !/^[a-f0-9]{32}$/.test(data.id) || !/^[a-f0-9]{32}$/.test(data.sourceId) || !['createMeal','updateMeal','planActivity','confirmActivity','moveActivity'].includes(data.type)) fail();
  const creates = ['createMeal','planActivity'].includes(data.type);
  if (creates ? data.targetId !== null : !positive(data.targetId)) fail();
  if (!Array.isArray(data.expected) || data.expected.length > 250 || Buffer.byteLength(JSON.stringify(data)) > 60000) fail();
  for (const row of data.expected) {
    exact(row, ['kind','id','revision']);
    if (typeof row.kind !== 'string' || typeof row.id !== 'string' || !positive(row.revision)) fail();
  }
  const v = data.values;
  if (data.type.endsWith('Meal')) {
    exact(v, ['name','category','plannedAt','notes','ingredients']);
    if (!['breakfast','secondBreakfast','lunch','snack','afternoonSnack','dinner'].includes(v.category)) fail();
    if (typeof v.name !== 'string' || !v.name.trim() || v.name.length > 120 || typeof v.notes !== 'string' || v.notes.length > 2000 || !future(v.plannedAt,checkTime) || !Array.isArray(v.ingredients) || v.ingredients.length < 1 || v.ingredients.length > 30) fail();
    for (const item of v.ingredients) {
      exact(item, ['ingredientId','catalogId','catalogRevision','grams']);
      const local=positive(item.ingredientId)&&item.catalogId===null&&item.catalogRevision===null;
      const catalog=item.ingredientId===null&&typeof item.catalogId==='string'&&/^usda_[1-9][0-9]*$/.test(item.catalogId)&&item.catalogId.length<=80&&typeof item.catalogRevision==='string'&&/^[a-f0-9]{64}$/.test(item.catalogRevision);
      if ((!local&&!catalog) || typeof item.grams !== 'number' || !Number.isFinite(item.grams) || item.grams <= 0 || item.grams > 10000) fail();
    }
    if (new Set(v.ingredients.map(row => row.ingredientId===null?'catalog:'+row.catalogId:'local:'+row.ingredientId)).size !== v.ingredients.length) fail();
  } else if (data.type === 'planActivity') {
    exact(v, ['activityId','startedAt','durationMinutes']);
    if (!positive(v.activityId) || !future(v.startedAt,checkTime) || !positive(v.durationMinutes) || v.durationMinutes > 1440) fail();
  } else if (data.type === 'moveActivity') {
    exact(v, ['startedAt']); if (!future(v.startedAt,checkTime)) fail();
  } else { exact(v, []); }
}
function scopeRows(rows, plan) {
  const selected = new Map();
  const add = (kind, id) => {
    const row = rows.find(r => r.kind === kind && r.id === String(id) && !r.deleted);
    if (!row) throw new FamilyError('failed-precondition');
    selected.set(`${kind}/${row.id}`, row); return row.payload;
  };
  if (plan.type.endsWith('Meal')) {
    if (plan.type === 'updateMeal') {
      add('meals', plan.targetId);
      for (const row of rows.filter(r => ['mealIngredients','mealHistory','mealSnapshots'].includes(r.kind) && !r.deleted && r.payload.meal_id === plan.targetId)) {
        selected.set(`${row.kind}/${row.id}`, row);
        if (row.kind === 'mealIngredients') {
          add('ingredients', row.payload.ingredient_id);
          if (row.payload.portion_id) add('portions', row.payload.portion_id);
        }
      }
    }
    for (const item of plan.values.ingredients) if(item.ingredientId!==null) add('ingredients', item.ingredientId);
  } else if (plan.type === 'planActivity') { add('activities', plan.values.activityId); }
  else {
    const occurrence = add('activityOccurrences', plan.targetId);
    add('activities', occurrence.activity_id);
    if (occurrence.schedule_id) add('activitySchedules', occurrence.schedule_id);
    if (occurrence.activity_log_id) add('activityLogs', occurrence.activity_log_id);
  }
  return [...selected.values()].sort((a,b) => `${a.kind}/${a.id}`.localeCompare(`${b.kind}/${b.id}`));
}
const versions = rows => rows.map(({kind,id,revision}) => ({kind,id,revision})).sort((a,b) => `${a.kind}/${a.id}`.localeCompare(`${b.kind}/${b.id}`));
module.exports = {validatePlan, scopeRows, versions};
