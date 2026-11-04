import 'package:diabeatthis/common/ingredient_catalog/ingredient_match_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefix search remains supported for multiword typed queries', () {
    expect(ingredientMatchScore('boil pot', 'Potatoes boiled'), 1);
    expect(ingredientMatchScore('ziem got', 'Ziemniaki gotowane'), 1);
  });
  test('word order and USDA punctuation do not affect exact food terms', () {
    expect(ingredientMatchScore('boiled potatoes', 'Potatoes, boiled'), 1);
    expect(ingredientMatchScore('potatoes cooked', 'Cooked potatoes'), 1);
  });
  test(
    'raw product cannot substitute cooked food and unrelated foods score zero',
    () {
      expect(
        ingredientMatchScore('cooked chicken breast', 'Chicken breast, raw'),
        0,
      );
      expect(ingredientMatchScore('boiled potatoes', 'Rice, boiled'), 0);
    },
  );
  test(
    'full queries omit filler and stay within catalog token and length bounds',
    () {
      expect(
        ingredientCatalogQuery('Potatoes, boiled, without skin'),
        'potatoes boiled skin',
      );
      expect(
        ingredientCatalogQuery(
          'one two three four five six seven eight nine ten',
        ).split(' '),
        hasLength(8),
      );
    },
  );
}
