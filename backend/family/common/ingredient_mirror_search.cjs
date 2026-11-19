'use strict';

function words(text) {
  return String(text ?? '').toLowerCase().replaceAll('ł', 'l').normalize('NFKD')
    .replace(/\p{M}/gu, '').match(/[\p{L}\p{N}]+/gu) ?? [];
}

function ingredientWords(payload) {
  return [...words(payload?.name), ...words(payload?.brand)];
}

function ingredientSearchPrefixes(payload) {
  const prefixes = new Set();
  for (const word of ingredientWords(payload).slice(0, 40)) {
    const letters = Array.from(word);
    for (let length = 2; length <= Math.min(letters.length, 32); length++) {
      prefixes.add(letters.slice(0, length).join(''));
    }
  }
  return [...prefixes];
}

function matchesIngredientWords(payload, query) {
  const terms = ingredientWords(payload);
  return query.every(term => terms.some(word => word.startsWith(term)));
}

module.exports = {words, ingredientSearchPrefixes, matchesIngredientWords};
