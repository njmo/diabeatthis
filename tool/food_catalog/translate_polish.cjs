'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { authenticatedClient } = require('./common/firestore.cjs');
const model = 'gemini-3-flash-preview';
const dataDir = path.join(__dirname, 'data');
const cacheDir = path.join(dataDir, 'translation-batches-pl');

const instruction = `Translate English USDA food descriptions into accurate, natural Polish for a food picker.
Return JSON with a translations array. Return exactly one entry per input ID, preserving every ID.
Each entry: id, name (concise Polish food and preparation name), details (Polish distinguishing qualifiers), aliases (2 to 4 useful Polish search phrases), needs_review (boolean), review_notes (array of short Polish explanations).
Preserve all distinctions across name and details: cooked/raw, boiled/baked/fried, skin, lean vs fat, bones, fat percentage, salt, enriched/unenriched, drained solids, fresh/frozen/canned, flour type, whole-grain.
Never change facts, infer recipes, add ingredients, or translate a generic food as a Polish prepared dish. Do not output nutrition.
Use Polish cooking terms. Translate broiled as opiekane, braised as duszone, boiled as gotowane, roasted as pieczone, grilled as grillowane.
USDA Choice and USDA Select are US meat grades: retain the grade names with USDA, not literal Polish choices.
US beef cuts do not always have exact Polish equivalents. Preserve uncertain anatomical English terms in details and set needs_review=true rather than invent a precise equivalent.
"separable lean only" means the lean part only; "separable lean and fat" includes the separable fat.
"trimmed to 0 inch fat" describes external fat trimming, not 0% total fat. Preserve original numeric qualifiers and units, do not silently convert fractions or measurements.
Keep brands and cultivars when present. Omit the USDA distribution-program footnote from the concise name; it may remain in details.
Aliases must describe the same food or a broader matching food family, not a different preparation or meat cut. Include useful singular/plural names when natural. Polish diacritics are allowed; search normalization handles their removal.
For potatoes, aliases can include ziemniaki and kartofle. For brown rice use ryż brązowy, not a different product like kasza. Never call soy flour wheat flour.
Names should generally be 15-110 characters, details at most 600 characters, aliases at most 100 characters each.
needs_review=false means no translation ambiguity detected by the model, not human approval.`;

const schema = {
  type: 'OBJECT', required: ['translations'], properties: {
    translations: { type: 'ARRAY', items: { type: 'OBJECT', required: ['id','name','details','aliases','needs_review','review_notes'], properties: {
      id: {type:'STRING'}, name:{type:'STRING'}, details:{type:'STRING'}, aliases:{type:'ARRAY',items:{type:'STRING'}}, needs_review:{type:'BOOLEAN'}, review_notes:{type:'ARRAY',items:{type:'STRING'}},
    } } },
  },
};

function validateBatch(batch, result) {
  if (!Array.isArray(result.translations) || result.translations.length !== batch.length) throw new Error('Translation batch count mismatch');
  const expected = new Set(batch.map(d=>d.id));
  for (const row of result.translations) {
    if (!expected.delete(row.id)) throw new Error('Unexpected or duplicate translation ID');
    if (typeof row.name !== 'string' || row.name.trim().length < 3 || row.name.length > 150 || typeof row.details !== 'string' || row.details.length > 900) throw new Error('Invalid translation text: '+row.id);
    if (!Array.isArray(row.aliases) || row.aliases.length < 1 || row.aliases.length > 8 || row.aliases.some(a=>typeof a!=='string'||!a.trim()||a.length>150)) throw new Error('Invalid aliases: '+row.id);
    if (typeof row.needs_review !== 'boolean' || !Array.isArray(row.review_notes)) throw new Error('Invalid review metadata');
    if (/[<>]/.test(row.name + row.details)) throw new Error('Unexpected markup in translation');
  }
  return result;
}

async function main() {
  fs.mkdirSync(cacheDir,{recursive:true});
  const foods=fs.readFileSync(path.join(dataDir,'ready.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
  await authenticatedClient('diabeatthis-e634c',path.join(dataDir,'firebase-context'));
  const {Client}=require(path.join(process.env.FIREBASE_TOOLS_LIB || path.join(require('node:os').homedir(),'.cache/firebase/tools/lib/node_modules/firebase-tools/lib'),'apiv2.js'));
  const client=new Client({urlPrefix:'https://aiplatform.googleapis.com',apiVersion:'v1'});
  const batches=[];
  for(let offset=0;offset<foods.length;offset+=40)batches.push(foods.slice(offset,offset+40));
  let next=0,completed=0;
  const results=new Array(batches.length);
  async function worker(){
    while(next<batches.length){
      const index=next++,batch=batches[index];
      const sourceHash=crypto.createHash('sha256').update(JSON.stringify(batch.map(d=>({id:d.id,name:d.name})))).digest('hex');
      const cache=path.join(cacheDir,`${sourceHash}.json`);
      if(fs.existsSync(cache))results[index]=validateBatch(batch,JSON.parse(fs.readFileSync(cache,'utf8')));
      else {
        let lastError;
        for(let attempt=0;attempt<3;attempt++){
          try{
            const response=await client.post(`/projects/diabeatthis-e634c/locations/global/publishers/google/models/${model}:generateContent`,{
              systemInstruction:{parts:[{text:instruction}]},
              contents:[{role:'user',parts:[{text:JSON.stringify(batch.map(d=>({id:d.id,name:d.name})))}]}],
              generationConfig:{responseMimeType:'application/json',responseSchema:schema,temperature:0,maxOutputTokens:14000,thinkingConfig:{thinkingLevel:'MINIMAL'}},
            },{timeout:180000});
            const candidate=response.body.candidates?.[0];
            if(candidate?.finishReason!=='STOP')throw new Error('Incomplete model output');
            const text=(candidate.content?.parts||[]).filter(p=>!p.thought&&p.text).map(p=>p.text).join('');
            results[index]=validateBatch(batch,JSON.parse(text));
            fs.writeFileSync(cache,JSON.stringify(results[index],null,2)+'\n');
            lastError=null;break;
          }catch(error){lastError=error;}
        }
        if(lastError)throw lastError;
      }
      completed++;console.log(`Translated ${completed}/${batches.length} batches`);
    }
  }
  await Promise.all([worker(),worker(),worker()]);
  const originals=new Map(foods.map(d=>[d.id,d]));
  const translations=results.flatMap(r=>r.translations).map(row=>({
    ingredientId:row.id,languageCode:'pl',name:row.name.trim(),details:row.details.trim(),aliases:[...new Set(row.aliases.map(a=>a.trim()))],
    status:row.needs_review?'needs_review':'machine_translated',reviewNotes:row.review_notes,
    translationVersion:1,sourceName:originals.get(row.id).name,sourceTextSha256:crypto.createHash('sha256').update(originals.get(row.id).name).digest('hex'),
    translationSource:{type:'model',model},
  })).sort((a,b)=>a.ingredientId.localeCompare(b.ingredientId));
  const output=path.join(dataDir,'translations-pl.jsonl');
  fs.writeFileSync(output,translations.map(d=>JSON.stringify(d)).join('\n')+'\n');
  const report={records:translations.length,machineTranslated:translations.filter(d=>d.status==='machine_translated').length,needsReview:translations.filter(d=>d.status==='needs_review').length,sha256:crypto.createHash('sha256').update(fs.readFileSync(output)).digest('hex'),model};
  fs.writeFileSync(path.join(dataDir,'translations-pl-manifest.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}

if(require.main===module)main().catch(error=>{console.error(error.message);process.exitCode=1;});
module.exports={validateBatch};
