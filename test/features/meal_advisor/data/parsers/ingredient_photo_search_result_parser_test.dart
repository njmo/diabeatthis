import 'package:diabeatthis/features/meal_advisor/data/parsers/ingredient_photo_search_result_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngredientPhotoSearchResultParser', () {
    test('parses recognized names and brand as lowercase candidates', () {
      const parser = IngredientPhotoSearchResultParser();

      final result = parser.parse('''
      {
        "names": ["Pieguski", "Ciastka"],
        "brand": "Milka"
      }
      ''');

      expect(result.names, ['pieguski', 'ciastka']);
      expect(result.brand, 'milka');
      expect(
        result.candidatesKey,
        '{"names":["pieguski","ciastka"],"brand":"milka"}',
      );
    });

    test('accepts a single name fallback', () {
      const parser = IngredientPhotoSearchResultParser();

      final result = parser.parse('{"name": "Ziemniaki", "brand": null}');

      expect(result.names, ['ziemniaki']);
      expect(result.brand, isNull);
      expect(result.candidatesKey, '{"names":["ziemniaki"]}');
    });
  });
}
