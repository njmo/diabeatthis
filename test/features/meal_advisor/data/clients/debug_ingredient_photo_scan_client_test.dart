import 'package:diabeatthis/features/meal_advisor/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/meal_advisor/data/parsers/ingredient_scan_result_parser.dart';
import 'package:diabeatthis/features/meal_advisor/domain/services/ingredient_scan_result_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = IngredientScanResultParser();
  const validator = IngredientScanResultValidator();

  Future<IngredientScanResult> scan(
    DebugIngredientPhotoScanScenario scenario,
  ) async {
    final client = DebugIngredientPhotoScanClient(
      scenario: scenario,
      delay: Duration.zero,
    );
    return validator.validate(parser.parse(await client.scan()));
  }

  group('DebugIngredientPhotoScanClient', () {
    test('returns complete recognized response', () async {
      final result = await scan(DebugIngredientPhotoScanScenario.recognized);

      expect(result.status, IngredientScanStatus.recognized);
      expect(result.hasRecognizedMinimumData, isTrue);
      expect(result.name, 'Testowy produkt');
    });

    test('returns retake response', () async {
      final result = await scan(DebugIngredientPhotoScanScenario.needsRetake);

      expect(result.status, IngredientScanStatus.needsRetake);
      expect(
        result.retakeRequest?.photo,
        IngredientScanPhotoTarget.nutritionLabel,
      );
    });

    test('returns incomplete response for review', () async {
      final result = await scan(
        DebugIngredientPhotoScanScenario.incompleteRecognized,
      );

      expect(result.status, IngredientScanStatus.needsReview);
      expect(result.name, 'Testowy produkt');
      expect(result.brand, isNull);
      expect(result.nutritionPer100g?.carbs, 62.3);
      expect(result.nutritionPer100g?.fat, isNull);
      expect(result.nutritionPer100g?.protein, 6.4);
      expect(result.nutritionPer100g?.fiber, isNull);
    });
  });
}
