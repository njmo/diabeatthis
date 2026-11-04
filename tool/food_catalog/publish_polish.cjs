'use strict';

const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const {isDeepStrictEqual}=require('node:util');
const {encode,decode,authenticatedClient,listDocuments}=require('./common/firestore.cjs');
const {compareExisting}=require('./import_firebase.cjs');
const {buildEntries,hash}=require('../../backend/ingredient_catalog/common/search.cjs');
const directory=path.join(__dirname,'data');
const project='diabeatthis-e634c';
const base=`projects/${project}/databases/(default)`;

async function batchRead(client,names){
  const found=new Map();
  for(let offset=0;offset<names.length;offset+=200){
    const response=await client.post(`/${base}/documents:batchGet`,{documents:names.slice(offset,offset+200)});
    const rows=Array.isArray(response.body)?response.body:[response.body];
    for(const row of rows){
      if(row.found)found.set(row.found.name,decode({mapValue:{fields:row.found.fields||{}}}));
      else if(!row.missing)throw new Error('Unrecognized batch read response');
    }
  }
  return found;
}

async function createAndVerify(client,documents,label){
  const existing=await batchRead(client,[...documents.keys()]);
  for(const [name,value]of existing)if(!isDeepStrictEqual(value,documents.get(name)))throw new Error('Existing document differs; no overwrite allowed: '+name);
  const missing=[...documents].filter(([name])=>!existing.has(name));
  for(let offset=0;offset<missing.length;offset+=150){
    const writes=missing.slice(offset,offset+150).map(([name,value])=>({update:{name,fields:encode(value).mapValue.fields},currentDocument:{exists:false}}));
    await client.post(`/${base}/documents:commit`,{writes});
    console.log(`${label}: created ${Math.min(offset+150,missing.length)}/${missing.length}`);
  }
  const after=await batchRead(client,[...documents.keys()]);
  if(after.size!==documents.size)throw new Error('Incomplete read-back verification');
  for(const[name,value]of documents)if(!isDeepStrictEqual(value,after.get(name)))throw new Error('Read-back mismatch: '+name);
  return {created:missing.length,verified:after.size};
}

async function main(){
  const execute=process.argv.includes('--execute');
  const audit=spawnSync('python3',[path.join(__dirname,'audit.py')],{encoding:'utf8'});
  if(audit.status!==0)throw new Error('Catalog audit failed: '+audit.stderr);
  const foods=fs.readFileSync(path.join(directory,'ready.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
  const raw=fs.readFileSync(path.join(directory,'translations-pl.jsonl'));
  const translations=raw.toString('utf8').trim().split('\n').map(JSON.parse);
  const manifest=JSON.parse(fs.readFileSync(path.join(directory,'translations-pl-manifest.json'),'utf8'));
  if(manifest.records!==foods.length||manifest.sha256!==crypto.createHash('sha256').update(raw).digest('hex'))throw new Error('Translation manifest mismatch');
  const entries=buildEntries(foods,translations);
  const digest=hash(entries),releaseId='pl-en-v1-'+digest.slice(0,20);
  const chunkList=[];
  for(let offset=0;offset<entries.length;offset+=150)chunkList.push({position:chunkList.length,entries:entries.slice(offset,offset+150)});
  const metadata={schemaVersion:1,releaseId,recordCount:entries.length,chunkCount:chunkList.length,sha256:digest,languages:['en','pl'],polishSearchable:entries.filter(e=>e.translations.pl).length};
  fs.writeFileSync(path.join(directory,'search-release.json'),JSON.stringify({metadata,chunks:chunkList})+'\n');
  if(!execute){console.log(JSON.stringify({translations:manifest,searchRelease:metadata,cloudWrites:0},null,2));return;}
  const client=await authenticatedClient(project,path.join(directory,'firebase-context'));
  // Verify nutrition records still equal the audited English source before any
  // translation write; no nutrition fields are updated by this publisher.
  compareExisting(foods,await listDocuments(client,`${base}/documents/common/ingredients/items`),true);
  const translated=new Map(translations.map(row=>[`${base}/documents/common/ingredients/items/${row.ingredientId}/translations/pl`,row]));
  const translationResult=await createAndVerify(client,translated,'Polish translations');
  const releasePath=`${base}/documents/common/ingredient_search/releases/${releaseId}`;
  const chunks=new Map(chunkList.map((chunk,index)=>[`${releasePath}/chunks/${String(index).padStart(4,'0')}`,chunk]));
  const chunkResult=await createAndVerify(client,chunks,'Search chunks');
  await createAndVerify(client,new Map([[releasePath,metadata]]),'Search release');
  const pointerName=`${base}/documents/common/ingredient_search`;
  const response=await client.get('/'+pointerName,{resolveOnHTTPError:true});
  const pointer={schemaVersion:1,catalog:'ingredients',activeRelease:releaseId};
  if(response.status!==404&&response.status!==200)throw new Error('Cannot read active search release');
  const old=response.status===200?decode({mapValue:{fields:response.body.fields||{}}}):null;
  if(old&&!isDeepStrictEqual(old,pointer)&&old.catalog!=='ingredients')throw new Error('Unexpected existing search namespace');
  if(!isDeepStrictEqual(old,pointer))await client.post(`/${base}/documents:commit`,{writes:[{
    update:{name:pointerName,fields:encode(pointer).mapValue.fields},
    currentDocument:old?{updateTime:response.body.updateTime}:{exists:false},
  }]});
  const verifiedPointer=await batchRead(client,[pointerName]);
  if(!isDeepStrictEqual(verifiedPointer.get(pointerName),pointer))throw new Error('Active release verification failed');
  // Confirm a translation import never changed the canonical nutrition data.
  compareExisting(foods,await listDocuments(client,`${base}/documents/common/ingredients/items`),true);
  const report={project,translations:translationResult,translationStates:{machineTranslated:manifest.machineTranslated,needsReview:manifest.needsReview},index:metadata,chunks:chunkResult,nutritionUnchanged:true,verifiedAt:new Date().toISOString()};
  fs.writeFileSync(path.join(directory,'polish-publish-report.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}
if(require.main===module)main().catch(error=>{console.error(error.message);process.exitCode=1;});
module.exports={batchRead,createAndVerify};
