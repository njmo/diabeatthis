'use strict';

const languages = ['pl', 'en'];

function sourceLanguage(food) {
  const language = food.languageCode ?? 'en';
  if (!languages.includes(language)) throw new Error('Unsupported source language');
  return language;
}

function validTranslation(translation, name) {
  return translation && ['machine_translated', 'reviewed'].includes(translation.status) &&
    translation.sourceName === name && typeof translation.name === 'string' && translation.name.trim()
    ? translation : null;
}

function displayFor(food, translations, languageCode) {
  const originalLanguage = sourceLanguage(food);
  const localized = languageCode === originalLanguage ? null : validTranslation(translations?.[languageCode], food.name);
  return {
    name: localized?.name || food.name,
    details: localized?.details || '',
    languageCode: localized ? languageCode : originalLanguage,
    translationStatus: localized?.status || 'source',
  };
}

module.exports = { languages, sourceLanguage, validTranslation, displayFor };
