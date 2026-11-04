'use strict';

const { hash, prepareEntries } = require('./search.cjs');

function createIndexCache(store, now = Date.now) {
  let cached, checkedAt = -Infinity, loading;
  async function load() {
    const pointer = (await store.doc('common/ingredient_search').get()).data();
    if (!pointer || !/^[a-z0-9-]{8,80}$/.test(pointer.activeRelease || '')) throw new Error('Search release is unavailable');
    if (cached?.releaseId === pointer.activeRelease) { checkedAt = now(); return cached; }
    const release = store.doc('common/ingredient_search/releases/' + pointer.activeRelease);
    const metadata = (await release.get()).data();
    if (!metadata || metadata.schemaVersion !== 1 || metadata.recordCount > 10000 || !Number.isInteger(metadata.chunkCount) || metadata.chunkCount < 1 || metadata.chunkCount > 100) throw new Error('Invalid search release');
    const chunks = await release.collection('chunks').orderBy('position').get();
    if (chunks.size !== metadata.chunkCount) throw new Error('Incomplete search release');
    const entries = chunks.docs.flatMap(document => document.data().entries);
    if (entries.length !== metadata.recordCount || hash(entries) !== metadata.sha256) throw new Error('Search release checksum mismatch');
    cached = { releaseId: pointer.activeRelease, prepared: prepareEntries(entries) };
    checkedAt = now();
    return cached;
  }
  return async function getIndex() {
    if (cached && now() - checkedAt < 60000) return cached;
    if (!loading) loading = load().finally(() => { loading = null; });
    return loading;
  };
}

module.exports = { createIndexCache };
