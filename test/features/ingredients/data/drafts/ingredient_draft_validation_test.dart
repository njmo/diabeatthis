import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngredientDraftValidation', () {
    test('uses UE carbs label mode by default', () {
      const ingredient = IngredientDraft.draft(
        name: 'Test',
        carbsPer100g: 1,
        fatPer100g: 1,
        fiberPer100g: 5,
        proteinPer100g: 1,
        nutritionConfidence: 0.8,
        isReference: false,
      );

      expect(ingredient.carbsLabelMode, CarbsLabelMode.eu);
      expect(ingredient.hasValidMacroRanges, true);
    });

    test('allows UE ingredient when fiber is greater than carbs', () {
      final ingredient = _ingredient(
        carbsPer100g: 1,
        fiberPer100g: 5,
        carbsLabelMode: CarbsLabelMode.eu,
      );

      expect(ingredient.hasValidMacroRanges, true);
      expect(ingredient.validateMacroRanges, returnsNormally);
    });

    test('rejects non-UE ingredient when net carbs would be zero', () {
      final ingredient = _ingredient(
        carbsPer100g: 5,
        fiberPer100g: 5,
        carbsLabelMode: CarbsLabelMode.nonEu,
      );

      expect(ingredient.hasValidMacroRanges, false);
      expect(ingredient.validateMacroRanges, throwsArgumentError);
    });

    test('rejects non-UE ingredient when net carbs would be negative', () {
      final ingredient = _ingredient(
        carbsPer100g: 1,
        fiberPer100g: 5,
        carbsLabelMode: CarbsLabelMode.nonEu,
      );

      expect(ingredient.hasValidMacroRanges, false);
      expect(ingredient.validateMacroRanges, throwsArgumentError);
    });

    test('rejects macros above 100g per 100g', () {
      final invalidMacros = [
        _ingredient(
          carbsPer100g: 101,
          fiberPer100g: 1,
          carbsLabelMode: CarbsLabelMode.eu,
        ),
        _ingredient(
          carbsPer100g: 10,
          fatPer100g: 101,
          fiberPer100g: 1,
          carbsLabelMode: CarbsLabelMode.eu,
        ),
        _ingredient(
          carbsPer100g: 10,
          fiberPer100g: 101,
          carbsLabelMode: CarbsLabelMode.eu,
        ),
        _ingredient(
          carbsPer100g: 10,
          proteinPer100g: 101,
          fiberPer100g: 1,
          carbsLabelMode: CarbsLabelMode.eu,
        ),
      ];

      for (final ingredient in invalidMacros) {
        expect(ingredient.hasValidMacroRanges, false);
        expect(ingredient.validateMacroRanges, throwsArgumentError);
      }
    });

    test('allows empty or valid barcode and rejects invalid barcode', () {
      final emptyBarcode = _ingredient(
        carbsPer100g: 1,
        fiberPer100g: 1,
        carbsLabelMode: CarbsLabelMode.eu,
      );
      final validBarcode = emptyBarcode.copyWith(barcode: '5900385503415');
      final invalidBarcode = emptyBarcode.copyWith(barcode: '5900385503416');

      expect(emptyBarcode.hasValidBarcode, true);
      expect(validBarcode.hasValidBarcode, true);
      expect(validBarcode.validateBarcode, returnsNormally);
      expect(invalidBarcode.hasValidBarcode, false);
      expect(invalidBarcode.validateBarcode, throwsArgumentError);
    });
  });
}

IngredientDraft _ingredient({
  required double carbsPer100g,
  required double fiberPer100g,
  required CarbsLabelMode carbsLabelMode,
  double fatPer100g = 1,
  double proteinPer100g = 1,
}) {
  return IngredientDraft.draft(
    name: 'Test',
    carbsPer100g: carbsPer100g,
    fatPer100g: fatPer100g,
    fiberPer100g: fiberPer100g,
    proteinPer100g: proteinPer100g,
    nutritionConfidence: 0.8,
    isReference: false,
    carbsLabelMode: carbsLabelMode,
  );
}
