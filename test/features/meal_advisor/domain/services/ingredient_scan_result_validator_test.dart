import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/meal_advisor/domain/services/ingredient_scan_result_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = IngredientScanResultValidator();

  group('IngredientScanResultValidator', () {
    test('keeps complete recognized result unchanged', () {
      const result = IngredientScanResult(
        status: IngredientScanStatus.recognized,
        name: 'Pieguski',
        brand: 'Milka',
        nutritionPer100g: NutritionPer100g(
          carbs: 62.3,
          fat: 20.1,
          protein: 6.4,
          fiber: 3.2,
        ),
        portions: [],
        retakeRequest: null,
      );

      expect(validator.validate(result), same(result));
    });

    test('marks incomplete recognized result as needing review', () {
      const result = IngredientScanResult(
        status: IngredientScanStatus.recognized,
        name: 'Pieguski',
        brand: null,
        nutritionPer100g: NutritionPer100g(
          carbs: 62.3,
          fat: null,
          protein: 6.4,
          fiber: null,
        ),
        portions: [],
        retakeRequest: null,
      );

      final validated = validator.validate(result);

      expect(validated.status, IngredientScanStatus.needsReview);
      expect(validated.needsReview, isTrue);
      expect(validated.name, 'Pieguski');
      expect(validated.brand, isNull);
      expect(validated.nutritionPer100g?.carbs, 62.3);
      expect(validated.nutritionPer100g?.fat, isNull);
      expect(validated.nutritionPer100g?.protein, 6.4);
      expect(validated.nutritionPer100g?.fiber, isNull);
    });

    test('keeps retake request unchanged', () {
      const result = IngredientScanResult(
        status: IngredientScanStatus.needsRetake,
        name: null,
        brand: null,
        nutritionPer100g: null,
        portions: [],
        retakeRequest: IngredientScanRetakeRequest(
          photo: IngredientScanPhotoTarget.front,
          reason: 'blurry',
          message: 'Zrób zdjęcie jeszcze raz.',
        ),
      );

      expect(validator.validate(result), same(result));
    });
  });
}
