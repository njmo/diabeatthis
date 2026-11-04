'use strict';

const crypto = require('node:crypto');
const { languages, sourceLanguage, validTranslation, displayFor } = require('./localization.cjs');

function normalize(text) {
  return String(text).toLowerCase().replace(/ł/g, 'l').normalize('NFKD').replace(/\p{M}/gu, '').replace(/[^a-z0-9]+/g, ' ').trim().replace(/\s+/g, ' ');
}

function term(word) {
  for (const stem of ['ziemniak', 'kartof', 'gotowan', 'pieczon', 'smazon', 'brazow', 'dusz', 'grillowan', 'makaron']) {
    if (word.startsWith(stem)) return stem === 'kartof' ? 'ziemniak' : stem;
  }
  return ({ ryzu: 'ryz', ryzem: 'ryz', ryzowy: 'ryzowy', bialego: 'bial', bialy: 'bial', biala: 'bial', biale: 'bial', soli: 'sol' })[word] || word;
}

function tokens(text) { return normalize(text).split(' ').filter(Boolean).map(term); }
function stable(value) {
  if (Array.isArray(value)) return '[' + value.map(stable).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + stable(value[key])).join(',') + '}';
  return JSON.stringify(value);
}
function hash(value) { return crypto.createHash('sha256').update(stable(value)).digest('hex'); }

function buildEntries(foods, translations) {
  const localized = new Map();
  for (const translation of translations) {
    const language = translation.languageCode ?? 'pl';
    if (!languages.includes(language)) throw new Error('Unsupported translation language');
    const key = `${translation.ingredientId}:${language}`;
    if (localized.has(key)) throw new Error('Duplicate translation: ' + key);
    localized.set(key, translation);
  }
  return foods.map(food => {
    if (!/^usda_[1-9][0-9]*$/.test(food.id)) throw new Error('Unsupported catalog identity: ' + food.id);
    const languageCode = sourceLanguage(food);
    const selected = {};
    for (const language of languages) {
      const translation = localized.get(`${food.id}:${language}`);
      if (translation && translation.sourceName !== food.name) throw new Error('Stale translation: ' + food.id);
      selected[language] = validTranslation(translation, food.name);
    }
    return { id: food.id, source: 'firebase', name: food.name, languageCode,
      englishName: languageCode === 'en' ? food.name : selected.en?.name || null,
      group: food.basicFoodGroup, iconId: food.iconId, iconAssetPath: food.iconAssetPath,
      translations: selected };
  }).sort((a,b) => a.id.localeCompare(b.id));
}

function entryFood(entry) {
  return { name: entry.name ?? entry.englishName, languageCode: entry.languageCode ?? 'en' };
}

function entryTranslations(entry) {
  // Version-one releases did not retain sourceName on their validated translations.
  const name = entryFood(entry).name;
  return Object.fromEntries(Object.entries(entry.translations || {}).map(([language, value]) =>
    [language, value && { ...value, sourceName: value.sourceName ?? (entry.name === undefined ? name : undefined) }]));
}

function prepareEntries(entries) {
  return entries.map(entry => {
    const food = entryFood(entry);
    const translations = entryTranslations(entry);
    const fields = Object.fromEntries(languages.map(language => {
      const display = displayFor(food, translations, language);
      const translation = language === sourceLanguage(food) ? null : validTranslation(translations[language], food.name);
      return [language, [
        { value: display.name, weight: language === 'pl' && translation ? 14 : language === 'en' ? 10 : sourceLanguage(food) === 'pl' ? 14 : 4 },
        ...(translation?.aliases || []).map(value => ({ value, weight: 9 })),
        { value: display.details, weight: 2 },
        { value: food.name, weight: 4 },
      ].map(field => ({ ...field, normalized: normalize(field.value), tokens: tokens(field.value) }))];
    }));
    return { entry, fields };
  });
}

function searchCatalog(prepared, request, releaseId) {
  const languageCode = request.languageCode || 'pl';
  if (!['pl','en'].includes(languageCode)) throw new Error('Unsupported language');
  if (typeof request.query !== 'string' || request.query.length > 120) throw new Error('Invalid query');
  const query = normalize(request.query);
  const queryTokens = [...new Set(tokens(query))];
  const limit = request.limit === undefined ? 20 : request.limit;
  if (!Number.isInteger(limit) || limit < 1 || limit > 20 || queryTokens.length > 8) throw new Error('Invalid search limit or token count');
  if (query.length < 2) return { releaseId, items: [], nextCursor: null };
  const queryHash = hash({ query, languageCode });
  let offset = 0;
  if (request.cursor) {
    let cursor;
    try { cursor = JSON.parse(Buffer.from(request.cursor, 'base64url').toString('utf8')); } catch { throw new Error('Invalid cursor'); }
    if (cursor.releaseId !== releaseId) throw new Error('Catalog version changed');
    if (cursor.queryHash !== queryHash || !Number.isInteger(cursor.offset) || cursor.offset < 0 || cursor.offset > prepared.length) throw new Error('Cursor does not match query');
    offset = cursor.offset;
  }
  const matches = [];
  for (const row of prepared) {
    const fields = row.fields[languageCode];
    if (!queryTokens.every(q => fields.some(field => field.tokens.some(t => t.startsWith(q))))) continue;
    let score = 0;
    for (const q of queryTokens) {
      score += Math.max(...fields.map(field => field.tokens.some(t => t === q) ? field.weight * 3 : field.tokens.some(t => t.startsWith(q)) ? field.weight : 0));
    }
    if (fields[0].normalized === query) score += 150;
    else if (fields[0].normalized.startsWith(query)) score += 40;
    const display = displayFor(entryFood(row.entry), entryTranslations(row.entry), languageCode);
    matches.push({ score, entry: row.entry, display, name: display.name });
  }
  matches.sort((a,b) => b.score - a.score || a.name.length - b.name.length || a.entry.id.localeCompare(b.entry.id));
  const page = matches.slice(offset, offset + limit);
  return { releaseId, items: page.map(row => ({
    identity: { source: 'firebase', sourceId: row.entry.id }, name: row.name,
    details: row.display?.details || '', displayLanguageCode: row.display.languageCode,
    translationStatus: row.display.translationStatus, englishName: row.entry.englishName,
    iconId: row.entry.iconId, iconAssetPath: row.entry.iconAssetPath, group: row.entry.group,
  })), nextCursor: offset + limit < matches.length ? Buffer.from(JSON.stringify({ releaseId, queryHash, offset: offset + limit })).toString('base64url') : null };
}

module.exports = { normalize, tokens, stable, hash, buildEntries, prepareEntries, searchCatalog };
