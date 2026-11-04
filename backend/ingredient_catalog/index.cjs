'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { createIndexCache } = require('./common/index_cache.cjs');
const { displayFor, sourceLanguage, validTranslation } = require('./common/localization.cjs');
const { searchCatalog } = require('./common/search.cjs');

initializeApp();
const store = getFirestore();
const getIndex = createIndexCache(store);

exports.searchIngredients = onCall({
  region: 'europe-west1', enforceAppCheck: true,
  memory: '256MiB', timeoutSeconds: 15, minInstances: 0, maxInstances: 4, concurrency: 20,
}, async request => {
  const data = request.data;
  if (!data || typeof data !== 'object' || Array.isArray(data) || (data.cursor && (typeof data.cursor !== 'string' || data.cursor.length > 1000))) throw new HttpsError('invalid-argument', 'Invalid search request');
  const index = await getIndex().catch(() => { throw new HttpsError('unavailable', 'Ingredient catalog is temporarily unavailable'); });
  try { return searchCatalog(index.prepared, data, index.releaseId); }
  catch (error) { throw new HttpsError(error.message === 'Catalog version changed' ? 'failed-precondition' : 'invalid-argument', error.message); }
});

exports.getCatalogIngredient = onCall({
  region: 'europe-west1', enforceAppCheck: true,
  memory: '256MiB', timeoutSeconds: 15, minInstances: 0, maxInstances: 4,
}, async request => {
  const { sourceId, languageCode = 'pl' } = request.data || {};
  if (typeof sourceId !== 'string' || sourceId.length > 80 || !/^usda_[1-9][0-9]*$/.test(sourceId) || !['pl','en'].includes(languageCode)) throw new HttpsError('invalid-argument', 'Invalid ingredient identity');
  const ref = store.doc('common/ingredients/items/' + sourceId);
  const [food, translation, englishTranslation] = await Promise.all([
    ref.get(), ref.collection('translations').doc(languageCode).get(),
    languageCode === 'en' ? Promise.resolve(null) : ref.collection('translations').doc('en').get(),
  ]);
  if (!food.exists) throw new HttpsError('not-found', 'Ingredient does not exist');
  const value = food.data();
  const translated = translation?.exists ? translation.data() : null;
  const display = displayFor(value, { [languageCode]: translated }, languageCode);
  const english = languageCode === 'en' ? translated : englishTranslation?.data();
  const englishName = sourceLanguage(value) === 'en' ? value.name : validTranslation(english, value.name)?.name || null;
  return { identity: { source: 'firebase', sourceId }, ingredient: value, display, englishName };

});
