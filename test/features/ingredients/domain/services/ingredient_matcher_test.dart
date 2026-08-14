import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/features/ingredients/domain/services/ingredient_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngredientMatcher', () {
    const matcher = IngredientMatcher();

    test('matches normalized ingredient name', () {
      final ingredient = _ingredient(name: 'Jogurt naturalny');

      final match = matcher.findByNameAndBrand(
        candidates: [ingredient],
        name: 'Jogurt-naturalny',
        brand: null,
      );

      expect(match, ingredient);
    });

    test('prefers matching brand and then empty local brand', () {
      final emptyBrand = _ingredient(id: 1, brand: null);
      final matchingBrand = _ingredient(id: 2, brand: 'Bavaria');
      final otherBrand = _ingredient(id: 3, brand: 'Inna marka');

      expect(
        matcher.findByNameAndBrand(
          candidates: [emptyBrand, matchingBrand, otherBrand],
          name: 'Bavaria 0,0% Ginger Lime',
          brand: 'Bavaria',
        ),
        matchingBrand,
      );

      expect(
        matcher.findByNameAndBrand(
          candidates: [otherBrand, emptyBrand],
          name: 'Bavaria 0,0% Ginger Lime',
          brand: 'Bavaria',
        ),
        emptyBrand,
      );
    });

    test('does not match partial names', () {
      final ingredient = _ingredient(name: 'Bavaria 0,0% Ginger Lime');

      final match = matcher.findByNameAndBrand(
        candidates: [ingredient],
        name: 'Bavaria Ginger',
        brand: 'Bavaria',
      );

      expect(match, isNull);
    });
  });
}

Ingredient _ingredient({
  int id = 1,
  String name = 'Bavaria 0,0% Ginger Lime',
  String? brand,
}) {
  return Ingredient(
    id: id,
    name: name,
    brand: brand,
    carbsPer100g: 7,
    fatPer100g: 0,
    fiberPer100g: 0,
    proteinPer100g: 0,
    nutritionConfidence: 0.8,
    isReference: false,
  );
}
