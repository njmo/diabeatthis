'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {validateRecord} = require('../common/mirror_service.cjs');

test('nutrition history has an explicit bounded projection without raw payloads', () => {
  const record = {
    kind: 'ingredientHistory', id: '1', revision: 1, deleted: false,
    payload: {id: 1, ingredient_id: 2, carbs_per_100g: 40, fat_per_100g: 2,
      fiber_per_100g: 3, protein_per_100g: 8, nutrition_confidence: 1, created_at: 1234},
  };
  assert.doesNotThrow(() => validateRecord(record));
  assert.throws(() => validateRecord({...record, payload: {...record.payload, raw_ai_response: 'private'}}));
  assert.throws(() => validateRecord({...record, id: '2'}));
  assert.doesNotThrow(() => validateRecord({...record, revision: 2, deleted: true, payload: null}));
});
