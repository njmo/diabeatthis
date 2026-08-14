import '../../../../core/domain/model/ingredient.dart' as domain;

class IngredientMatcher {
  const IngredientMatcher();

  domain.Ingredient? findByNameAndBrand({
    required Iterable<domain.Ingredient> candidates,
    required String name,
    required String? brand,
  }) {
    final normalizedName = normalizeIngredientMatchText(name);
    final normalizedBrand = normalizeIngredientMatchText(brand ?? '');
    final matchingNameIngredients = candidates
        .where(
          (ingredient) =>
              normalizeIngredientMatchText(ingredient.name) == normalizedName,
        )
        .toList(growable: false);

    if (matchingNameIngredients.isEmpty) {
      return null;
    }

    if (normalizedBrand.isNotEmpty) {
      for (final ingredient in matchingNameIngredients) {
        if (normalizeIngredientMatchText(ingredient.brand ?? '') ==
            normalizedBrand) {
          return ingredient;
        }
      }

      for (final ingredient in matchingNameIngredients) {
        if (normalizeIngredientMatchText(ingredient.brand ?? '').isEmpty) {
          return ingredient;
        }
      }
    }

    return matchingNameIngredients.first;
  }
}

String normalizeIngredientMatchText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '')
      .trim();
}
