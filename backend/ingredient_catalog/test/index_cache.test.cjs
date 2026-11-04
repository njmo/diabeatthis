'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createIndexCache } = require('../common/index_cache.cjs');
const { hash } = require('../common/search.cjs');

function fixture() {
  const entries = [{ id:'usda_1',englishName:'Rice, cooked',translations:{pl:null} }];
  const state = { active:'release-one',time:0,reads:0,corrupt:false };
  const store = { doc(name) {
    return {
      async get() {
        state.reads++;
        if(name==='common/ingredient_search')return {data:()=>({activeRelease:state.active})};
        return {data:()=>({schemaVersion:1,recordCount:1,chunkCount:1,sha256:state.corrupt?'wrong':hash(entries)})};
      },
      collection(){return {orderBy(){return {async get(){state.reads++;return {size:1,docs:[{data:()=>({position:0,entries})}]};}};}};},
    };
  } };
  return {state,get:createIndexCache(store,()=>state.time)};
}

test('Concurrent cold requests share one load, and warm requests use memory', async()=>{
  const {state,get}=fixture();
  const [a,b]=await Promise.all([get(),get()]);
  assert.equal(a,b);assert.equal(state.reads,3);
  await get();assert.equal(state.reads,3);
  state.time=60001;await get();assert.equal(state.reads,4);
});
test('An active version change reloads the index after the bounded cache interval',async()=>{
  const {state,get}=fixture();await get();state.active='release-two';state.time=60001;
  assert.equal((await get()).releaseId,'release-two');assert.equal(state.reads,6);
});
test('A corrupt release is rejected rather than served as valid data',async()=>{
  const {state,get}=fixture();state.corrupt=true;await assert.rejects(get(),/checksum/);
  state.corrupt=false;assert.equal((await get()).releaseId,'release-one');
});
