'use strict';

const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const {authenticatedClient,decode,listDocuments}=require('./common/firestore.cjs');
const {createIndexCache}=require('../../backend/ingredient_catalog/common/index_cache.cjs');
const {searchCatalog}=require('../../backend/ingredient_catalog/common/search.cjs');

async function main(){
  const client=await authenticatedClient('diabeatthis-e634c',path.join(__dirname,'data/firebase-context'));
  const base='projects/diabeatthis-e634c/databases/(default)/documents/';
  let requests=0;
  const store={doc(name){return {
    async get(){requests++;const response=await client.get('/'+base+name);return {data:()=>decode({mapValue:{fields:response.body.fields||{}}})};},
    collection(collection){return {orderBy(){return {async get(){requests++;const result=await listDocuments(client,base+name+'/'+collection);const data=[...result.values()].sort((a,b)=>a.position-b.position);return {size:data.length,docs:data.map(value=>({data:()=>value}))};}};}};},
  };}};
  const load=createIndexCache(store);
  const index=await load();
  const checks=[];
  for(const query of ['ryz braz','brązowego ryżu','gotowane ziemniaki','maka pszenna','bulka tarta','oliwa','kurczak piers']){
    const result=searchCatalog(index.prepared,{query,languageCode:'pl',limit:20},index.releaseId);
    assert.ok(result.items.length>0,query);
    assert.ok(result.items.every(item=>item.identity.source==='firebase'&&item.displayLanguageCode==='pl'));
    checks.push({query,results:result.items.length,first:result.items[0].name});
  }
  const first=searchCatalog(index.prepared,{query:'wolowina',limit:2},index.releaseId);
  assert.ok(first.nextCursor);
  const second=searchCatalog(index.prepared,{query:'wolowina',limit:2,cursor:first.nextCursor},index.releaseId);
  assert.ok(second.items.every(b=>!first.items.some(a=>a.identity.sourceId===b.identity.sourceId)));
  const fallback=searchCatalog(index.prepared,{query:'abiyuch'},index.releaseId);
  assert.equal(fallback.items[0].displayLanguageCode,'en');
  const previous=requests;await load();assert.equal(requests,previous);
  const report={releaseId:index.releaseId,records:index.prepared.length,checks,pagination:'passed',englishFallback:'passed',warmCache:'passed',cloudWrites:0};
  fs.writeFileSync(path.join(__dirname,'data/polish-search-verification.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
