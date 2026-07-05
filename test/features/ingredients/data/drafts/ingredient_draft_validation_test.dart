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
  });
}

IngredientDraft _ingredient({
  required double carbsPer100g,
  required double fiberPer100g,
  required CarbsLabelMode carbsLabelMode,
}) {
  return IngredientDraft.draft(
    name: 'Test',
    carbsPer100g: carbsPer100g,
    fatPer100g: 1,
    fiberPer100g: fiberPer100g,
    proteinPer100g: 1,
    nutritionConfidence: 0.8,
    isReference: false,
    carbsLabelMode: carbsLabelMode,
  );
}
