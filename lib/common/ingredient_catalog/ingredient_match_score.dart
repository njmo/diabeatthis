import 'ingredient_search_normalizer.dart';

const ingredientSearchStopWords = {
  'a',
  'an',
  'the',
  'and',
  'of',
  'with',
  'without',
  'in',
  'or',
  'to',
  'for',
};

Set<String> ingredientSearchTerms(String value) =>
    normalizeIngredientSearch(value)
        .split(' ')
        .where(
          (word) =>
              word.isNotEmpty && !ingredientSearchStopWords.contains(word),
        )
        .map(
          (word) => word == 'potatoes'
              ? 'potato'
              : word == 'tomatoes'
              ? 'tomato'
              : word,
        )
        .toSet();

/// Order-independent matching; incompatible preparation must not auto-match.
double ingredientMatchScore(String query, String name) {
  final wanted = ingredientSearchTerms(query);
  final actual = ingredientSearchTerms(name);
  if (wanted.isEmpty || actual.isEmpty) return 0;
  const sauces = {'sos', 'sauce', 'dip', 'dressing', 'gravy'};
  if (wanted.any(sauces.contains) && !actual.any(sauces.contains)) return 0;
  const cooked = {
    'cooked',
    'boiled',
    'roasted',
    'fried',
    'grilled',
    'baked',
    'steamed',
  };
  if ((wanted.contains('raw') && actual.any(cooked.contains)) ||
      (actual.contains('raw') && wanted.any(cooked.contains))) {
    return 0;
  }
  const preparation = {...cooked, 'raw', 'skin', 'salt', 'unsalted', 'salted'};
  final foodTerms = wanted.difference(preparation);
  final specificTerms = foodTerms.difference({'sos', 'sauce', 'prepared'});
  final food = specificTerms.isEmpty ? foodTerms : specificTerms;
  bool matches(String term) => actual.any((word) => word.startsWith(term));
  if (food.isEmpty || !food.any(matches)) return 0;
  final overlap = wanted.where(matches).length;
  return 2 * overlap / (wanted.length + actual.length);
}

/// Search and automatic assignment use the same displayed and source names.
double ingredientNameMatchScore(
  String query,
  String name,
  String? englishName,
) {
  final displayed = ingredientMatchScore(query, name);
  final source = englishName == null
      ? 0.0
      : ingredientMatchScore(query, englishName);
  return displayed > source ? displayed : source;
}

String ingredientCatalogQuery(String query) {
  final terms = normalizeIngredientSearch(query)
      .split(' ')
      .where(
        (word) => word.isNotEmpty && !ingredientSearchStopWords.contains(word),
      )
      .take(8)
      .join(' ');
  return terms.substring(0, terms.length.clamp(0, 120));
}
