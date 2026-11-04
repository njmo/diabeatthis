'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const {validateBatch}=require('./translate_polish.cjs');
const {semanticIssues}=require('./validate_translations.cjs');

test('Translation batches preserve exact source IDs',()=>{
  const source=[{id:'usda_1',name:'Rice'}];
  const row={id:'usda_1',name:'Ryż',details:'Gotowany',aliases:['ryż'],needs_review:false,review_notes:[]};
  assert.doesNotThrow(()=>validateBatch(source,{translations:[row]}));
  assert.throws(()=>validateBatch(source,{translations:[{...row,id:'usda_2'}]}));
  assert.throws(()=>validateBatch(source,{translations:[]}));
  assert.throws(()=>validateBatch(source,{translations:[{...row,aliases:[]}]}));
});
test('Preparation and numeric distinctions are checked without altering nutrition',()=>{
  assert.ok(semanticIssues('Rice, raw',{name:'Ryż gotowany',details:''}).length);
  assert.ok(semanticIssues('Potatoes, boiled, without salt',{name:'Ziemniaki gotowane',details:'Z solą'}).length);
  assert.ok(semanticIssues('Milk, 3.25% milkfat',{name:'Mleko 2%',details:''}).length);
  assert.deepEqual(semanticIssues('Milk, 3.25% milkfat',{name:'Mleko 3,25%',details:''}),[]);
  assert.deepEqual(semanticIssues('Potatoes, boiled, without salt',{name:'Ziemniaki gotowane',details:'Bez dodatku soli'}),[]);
});
