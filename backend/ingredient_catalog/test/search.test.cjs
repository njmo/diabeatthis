'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { normalize, prepareEntries, searchCatalog, buildEntries } = require('../common/search.cjs');

function row(id, englishName, name, aliases = [], details = '') {
  return { id, englishName, group: 'example', iconId: 'rice', iconAssetPath: 'assets/icons/food/rice.png', translations: { pl: { name, details, aliases, status: 'machine_translated' } } };
}
const entries = [row('usda_1','Rice, brown, cooked','Ryż brązowy, ugotowany',['ryż brązowy']),row('usda_2','Rice, white, cooked','Ryż biały, ugotowany',['ryż biały']),row('usda_3','Potatoes, boiled','Ziemniaki gotowane',['kartofle gotowane'],'Bez soli'),row('usda_4','Rice flour','Mąka ryżowa',['mąka z ryżu'])];
const prepared = prepareEntries(entries);

test('Polish diacritics including ł are normalized', () => assert.equal(normalize('BIAŁY  Ryż'), 'bialy ryz'));
test('All query words match regardless of order and Polish suffixes', () => {
  for (const query of ['ryz braz','brązowego ryżu','gotowane ziemniaki','kartofle','ziemniaków gotowanych']) {
    const result = searchCatalog(prepared,{query},'release-one');
    assert.equal(result.items[0].identity.sourceId,query.includes('ry')?'usda_1':'usda_3');
  }
  assert.equal(searchCatalog(prepared,{query:'ryz braz bia'},'release-one').items.length,0);
});
test('English fallback and prefix search work without Polish translation', () => {
  const p=prepareEntries([{...entries[0],translations:{pl:null}}]);
  const result=searchCatalog(p,{query:'rice'},'release-one');
  assert.equal(result.items[0].displayLanguageCode,'en');
});
test('Pagination cannot cross a different query or release', () => {
  const first=searchCatalog(prepared,{query:'ryz',limit:1},'release-one');
  assert.ok(first.nextCursor);
  const second=searchCatalog(prepared,{query:'ryz',limit:1,cursor:first.nextCursor},'release-one');
  assert.notEqual(first.items[0].identity.sourceId,second.items[0].identity.sourceId);
  assert.throws(()=>searchCatalog(prepared,{query:'ziemniaki',cursor:first.nextCursor},'release-one'));
  assert.throws(()=>searchCatalog(prepared,{query:'ryz',cursor:first.nextCursor},'release-two'));
  assert.throws(()=>searchCatalog(prepared,{query:'ryz',cursor:'invalid'},'release-one'));
});
test('Small queries cannot fetch the full catalog and limits are enforced', () => {
  assert.deepEqual(searchCatalog(prepared,{query:''},'release-one').items,[]);
  assert.throws(()=>searchCatalog(prepared,{query:'rice',limit:1000},'release-one'));
  assert.throws(()=>searchCatalog(prepared,{query:'rice',languageCode:'unknown'},'release-one'));
});
test('Ambiguous or stale translations are not silently published as Polish', () => {
  const food={id:'usda_1',name:'Rice',basicFoodGroup:'grain',iconId:'rice',iconAssetPath:'rice.png'};
  const built=buildEntries([food],[{ingredientId:'usda_1',sourceName:'Rice',status:'needs_review'}]);
  assert.equal(built[0].translations.pl,null);
  assert.throws(()=>buildEntries([food],[{ingredientId:'usda_1',sourceName:'Other',status:'machine_translated'}]));
});
