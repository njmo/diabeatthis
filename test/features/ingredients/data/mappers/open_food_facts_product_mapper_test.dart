import 'package:diabeatthis/features/ingredients/data/clients/open_food_facts_product_client.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/open_food_facts_product_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenFoodFactsProductMapper', () {
    const mapper = OpenFoodFactsProductMapper();

    test('maps product response to ingredient scan result', () {
      final result = mapper.map('5449000000996', {
        'status': 1,
        'product': {
          'product_name': 'Coca-Cola Original Taste',
          'brands_tags': ['coca-cola'],
          'serving_size': '330 ml',
          'serving_quantity': 330,
          'nutriments': {
            'carbohydrates_100g': 10.6,
            'fat_100g': 0,
            'proteins_100g': 0,
            'fiber_100g': 0,
          },
        },
      });

      expect(result.status, IngredientScanStatus.recognized);
      expect(result.name, 'Coca-Cola Original Taste');
      expect(result.brand, 'coca cola');
      expect(result.nutritionPer100g?.carbs, 10.6);
      expect(result.nutritionPer100g?.fat, 0);
      expect(result.nutritionPer100g?.protein, 0);
      expect(result.nutritionPer100g?.fiber, 0);
      expect(result.portions.single.grams, 330);
      expect(result.portions.single.name, '330 ml');
    });

    test('throws when product is missing', () {
      expect(
        () => mapper.map('12345678', {'status': 0}),
        throwsA(isA<OpenFoodFactsProductNotFoundException>()),
      );
    });
  });
}
