import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/meal_advisor/data/parsers/ingredient_scan_result_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = IngredientScanResultParser();

  group('IngredientScanResultParser', () {
    test('parses nutrition per 100g and recognized portions', () {
      final result = parser.parse('''
```json
{
  "status": "recognized",
  "name": "Pieguski",
  "brand": "Milka",
  "nutritionPer100g": {
    "carbs": 62.3,
    "fat": 20.1,
    "protein": 6.4,
    "fiber": 3.2
  },
  "portions": [
    {
      "name": "2 ciastka",
      "unitHint": "ciastka",
      "grams": 25,
      "source": "nutrition_label"
    }
  ]
}
```
''');

      expect(result.name, 'Pieguski');
      expect(result.brand, 'Milka');
      expect(result.status, IngredientScanStatus.recognized);
      expect(result.needsRetake, isFalse);
      expect(result.hasCompleteNutritionPer100g, isTrue);
      expect(result.nutritionPer100g?.carbs, 62.3);
      expect(result.nutritionPer100g?.fat, 20.1);
      expect(result.nutritionPer100g?.protein, 6.4);
      expect(result.nutritionPer100g?.fiber, 3.2);
      expect(result.portions, hasLength(1));
      expect(result.portions.single.name, '2 ciastka');
      expect(result.portions.single.unitHint, 'ciastka');
      expect(result.portions.single.grams, 25);
      expect(result.portions.single.source, 'nutrition_label');
    });

    test('parses retake request without recognized nutrition data', () {
      final result = parser.parse('''
{
  "status": "needsRetake",
  "photo": "nutritionLabel",
  "reason": "blurry_or_incomplete",
  "message": "Tabela wartości odżywczych jest niewyraźna. Zrób zdjęcie jeszcze raz."
}
''');

      expect(result.status, IngredientScanStatus.needsRetake);
      expect(result.needsRetake, isTrue);
      expect(result.name, isNull);
      expect(result.brand, isNull);
      expect(result.nutritionPer100g, isNull);
      expect(result.portions, isEmpty);
      expect(
        result.retakeRequest?.photo,
        IngredientScanPhotoTarget.nutritionLabel,
      );
      expect(result.retakeRequest?.reason, 'blurry_or_incomplete');
      expect(
        result.retakeRequest?.message,
        'Tabela wartości odżywczych jest niewyraźna. Zrób zdjęcie jeszcze raz.',
      );
    });

    test('parses schema macro values from strings', () {
      final result = parser.parse('''
{
  "name": "Jogurt",
  "brand": "Test",
  "nutritionPer100g": {
    "carbs": "12,5 g",
    "fat": "3.1g",
    "protein": "4 g",
    "fiber": "0 g"
  }
}
''');

      expect(result.name, 'Jogurt');
      expect(result.brand, 'Test');
      expect(result.hasCompleteNutritionPer100g, isTrue);
      expect(result.nutritionPer100g?.carbs, 12.5);
      expect(result.nutritionPer100g?.fat, 3.1);
      expect(result.nutritionPer100g?.protein, 4);
      expect(result.nutritionPer100g?.fiber, 0);
      expect(result.portions, isEmpty);
    });

    test('ignores flat legacy macro values outside the schema', () {
      final result = parser.parse('''
{
  "name": "Jogurt",
  "brand": "Test",
  "carbs": "12,5 g",
  "fat": "3.1g",
  "protein": "4 g",
  "fiber": "0 g"
}
''');

      expect(result.name, 'Jogurt');
      expect(result.brand, 'Test');
      expect(result.hasCompleteNutritionPer100g, isFalse);
      expect(result.nutritionPer100g?.carbs, isNull);
      expect(result.nutritionPer100g?.fat, isNull);
      expect(result.nutritionPer100g?.protein, isNull);
      expect(result.nutritionPer100g?.fiber, isNull);
    });

    test('keeps invalid macro and portion numbers as null', () {
      final result = parser.parseMap({
        'nutritionPer100g': {
          'carbs': '-1',
          'fat': 'brak danych',
          'protein': 7,
          'fiber': 2,
        },
        'portions': [
          {'name': '1 sztuka', 'unitHint': 'szt.', 'grams': '-20 g'},
        ],
      });

      expect(result.hasCompleteNutritionPer100g, isFalse);
      expect(result.nutritionPer100g?.carbs, isNull);
      expect(result.nutritionPer100g?.fat, isNull);
      expect(result.nutritionPer100g?.protein, 7);
      expect(result.nutritionPer100g?.fiber, 2);
      expect(result.portions.single.grams, isNull);
    });

    test('throws when response does not contain a JSON object', () {
      expect(
        () => parser.parse('nie znaleziono danych'),
        throwsFormatException,
      );
    });
  });
}
