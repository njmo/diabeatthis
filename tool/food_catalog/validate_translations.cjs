'use strict';

const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {normalize}=require('../../backend/ingredient_catalog/common/search.cjs');
const directory=path.join(__dirname,'data');

function cleanCookingDescription(source,text){
  if(/\bboiled\b/i.test(source)||!/\b(?:roasted|baked|broiled|braised|grilled)\b/i.test(source))return text;
  return text
    .replace(/\bgotowane przez duszenie\b/gi,'duszone')
    .replace(/\bgotowana przez duszenie\b/gi,'duszona')
    .replace(/\bgotowany przez duszenie\b/gi,'duszony')
    .replace(/\bgotowane przez opiekanie\b/gi,'opiekane')
    .replace(/\bgotowana przez opiekanie\b/gi,'opiekana')
    .replace(/\bgotowany przez opiekanie\b/gi,'opiekany')
    .replace(/\b(?:u?gotowan[aye]),?\s+(?:i\s+)?(?=(?:pieczon|duszon|opiekan|grillowan))/gi,'');
}

function semanticIssues(source,translation){
  const text=normalize(translation.name+' '+translation.details);
  const issues=[];
  if(/\b(?:cooked|boiled)\b/i.test(source)&&!/(gotowan|ugotowan|pieczon|prazon|duszon|grillow|opiek|smazon)/.test(text))issues.push('Niepotwierdzony stan po obróbce cieplnej.');
  if(/\braw\b/i.test(source)&&!/(surow|nieprzetworzon)/.test(text))issues.push('Brak jednoznacznego oznaczenia surowego produktu.');
  if(/\b(?:without salt|no salt added)\b/i.test(source)&&!/(bez.{0,20}soli|niesolon)/.test(text))issues.push('Brak jednoznacznego oznaczenia bez soli.');
  if(/\bwith(?: added)? salt\b/i.test(source)&&!/(z.{0,10}sola|solon|dodatkiem soli)/.test(text))issues.push('Brak jednoznacznego oznaczenia dodatku soli.');
  if(/\b(?:flour|flours)\b/i.test(source)&&!/(maka|maki)/.test(text))issues.push('Brak oznaczenia mąki.');
  const numbers=text=>new Set((text.replace(/(\d),(\d)/g,'$1.$2').match(/\d+(?:[./]\d+)?/g)||[]));
  const expected=numbers(source),actual=numbers(translation.name+' '+translation.details);
  if([...expected].some(value=>!actual.has(value)))issues.push('Wymaga sprawdzenia zachowania liczbowych cech wariantu.');
  return issues;
}

function main(){
  const foods=fs.readFileSync(path.join(directory,'ready.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
  const source=new Map(foods.map(d=>[d.id,d]));
  const translations=fs.readFileSync(path.join(directory,'translations-pl.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
  const seen=new Set();
  for(const row of translations){
    if(!source.has(row.ingredientId)||seen.has(row.ingredientId))throw new Error('Unknown or repeated translation identity');
    seen.add(row.ingredientId);
    if(row.languageCode!=='pl'||row.sourceName!==source.get(row.ingredientId).name||row.sourceTextSha256!==crypto.createHash('sha256').update(row.sourceName).digest('hex'))throw new Error('Stale or invalid translation source');
    if(!row.name.trim()||!Array.isArray(row.aliases)||row.aliases.some(a=>!a.trim()))throw new Error('Invalid localized name or aliases');
    row.name=cleanCookingDescription(row.sourceName,row.name);
    row.details=cleanCookingDescription(row.sourceName,row.details);
    for(const field of ['carbsPer100g','fatPer100g','fiberPer100g','proteinPer100g'])if(field in row)throw new Error('Translations must not contain nutrition');
    const issues=semanticIssues(row.sourceName,row);
    if(issues.length){row.status='needs_review';row.reviewNotes=[...new Set([...row.reviewNotes,...issues])];}
  }
  if(seen.size!==source.size)throw new Error('Incomplete translation coverage');
  translations.sort((a,b)=>a.ingredientId.localeCompare(b.ingredientId));
  fs.writeFileSync(path.join(directory,'translations-pl.jsonl'),translations.map(d=>JSON.stringify(d)).join('\n')+'\n');
  const report={records:translations.length,machineTranslated:translations.filter(d=>d.status==='machine_translated').length,needsReview:translations.filter(d=>d.status==='needs_review').length,
    sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(directory,'translations-pl.jsonl'))).digest('hex'),model:translations[0].translationSource.model};
  fs.writeFileSync(path.join(directory,'translations-pl-manifest.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}
if(require.main===module)main();
module.exports={semanticIssues};
