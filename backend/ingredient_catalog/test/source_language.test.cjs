'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { buildEntries, prepareEntries, searchCatalog } = require('../common/search.cjs');
const { displayFor } = require('../common/localization.cjs');

const food = { id: 'usda_123', name: 'Ryż basmati Marka', languageCode: 'pl', carbsPer100g: 28 };
const english = { ingredientId: food.id, languageCode: 'en', sourceName: food.name,
  name: 'Basmati rice Marka', aliases: ['cooked basmati'], status: 'reviewed' };

function search(foods, translations, query, languageCode) {
  return searchCatalog(prepareEntries(buildEntries(foods, translations)), { query, languageCode }, 'release-test').items;
}

test('Polish original needs no translation and keeps its identity in either locale', () => {
  for (const language of ['pl', 'en']) {
    const [result] = search([food], [], 'ryz basmati', language);
    assert.equal(result.name, food.name);
    assert.equal(result.displayLanguageCode, 'pl');
    assert.equal(result.translationStatus, 'source');
    assert.equal(result.identity.sourceId, food.id);
    assert.equal(result.englishName, null);
  }
});

test('English translation and aliases resolve to the same original product', () => {
  const before = JSON.stringify(food);
  const [result] = search([food], [english], 'cooked basmati', 'en');
  assert.equal(result.name, english.name);
  assert.equal(result.displayLanguageCode, 'en');
  assert.equal(result.translationStatus, 'reviewed');
  assert.equal(result.identity.sourceId, food.id);
  assert.equal(search([food], [english], 'ryz basmati', 'pl')[0].name, food.name);
  assert.equal(JSON.stringify(food), before);
});

test('Detail display and search choose the same name and language', () => {
  for (const language of ['pl', 'en']) {
    const [result] = search([food], [english], 'basmati', language);
    const display = displayFor(food, { en: english }, language);
    assert.equal(result.name, display.name);
    assert.equal(result.displayLanguageCode, display.languageCode);
    assert.equal(result.translationStatus, display.translationStatus);
  }
});

test('Unreviewed and stale translations never replace original detail names', () => {
  for (const translation of [{ ...english, status: 'needs_review' }, { ...english, sourceName: 'Other' }]) {
    assert.equal(displayFor(food, { en: translation }, 'en').name, food.name);
  }
  assert.equal(search([food], [{ ...english, status: 'needs_review' }], 'rice', 'en').length, 0);
  assert.throws(() => buildEntries([food], [{ ...english, sourceName: 'Other' }]));
});

test('Missing source language remains English for existing USDA records', () => {
  const legacy = { id: 'usda_1', name: 'Rice, cooked' };
  assert.equal(search([legacy], [], 'rice', 'pl')[0].displayLanguageCode, 'en');
  assert.equal(displayFor(legacy, {}, 'pl').name, legacy.name);
});

test('Duplicate translations and unsupported source languages fail explicitly', () => {
  assert.throws(() => buildEntries([food], [english, english]));
  assert.throws(() => buildEntries([{ ...food, languageCode: 'unknown' }], []));
});

test('Publication cannot introduce identities rejected by the current app', () => {
  assert.throws(() => buildEntries([{ ...food, id: 'manufacturer_example' }], []));
});
