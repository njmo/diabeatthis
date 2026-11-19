'use strict';

const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {ingredientSearchPrefixes} = require('../common/ingredient_mirror_search.cjs');

async function backfill(store, apply) {
  let missing = 0;
  for await (const mirror of store.collection('userMirrors').stream()) {
    const ingredients = mirror.ref.collection('entities').where('kind', '==', 'ingredients');
    for await (const snapshot of ingredients.stream()) {
      const row = snapshot.data();
      if (row.deleted || Array.isArray(row.ingredientSearchPrefixes)) continue;
      missing++;
      if (apply) {
        await snapshot.ref.update({
          ingredientSearchPrefixes: ingredientSearchPrefixes(row.payload),
        }, {lastUpdateTime: snapshot.updateTime});
      }
    }
  }
  return missing;
}

if (require.main === module) {
  async function main([projectId, mode]) {
    if (!projectId || (mode !== undefined && mode !== '--apply')) {
      throw new Error('Usage: node tools/backfill_ingredient_search.cjs PROJECT_ID [--apply]');
    }
    const apply = mode === '--apply';
    const missing = await backfill(getFirestore(initializeApp({projectId})), apply);
    console.log(`${projectId}: ${missing} ingredient records ${apply ? 'indexed' : 'need indexing'}`);
  }
  main(process.argv.slice(2)).catch(error => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {backfill};
