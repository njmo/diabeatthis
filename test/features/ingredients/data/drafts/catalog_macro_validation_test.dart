import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oil = IngredientDraft.draft(
    name: 'Oil',
    carbsPer100g: 0,
    fiberPer100g: 0,
    fatPer100g: 100,
    proteinPer100g: 0,
    nutritionConfidence: 0,
    isReference: false,
    carbsLabelMode: CarbsLabelMode.nonEu,
  );
  test('US oil and meat with zero carbohydrates remain valid ingredients', () {
    expect(oil.validateMacroRanges, returnsNormally);
    expect(oil.hasValidMacroRanges, isTrue);
    final meat = oil.copyWith(fatPer100g: 10, proteinPer100g: 25);
    expect(meat.validateMacroRanges, returnsNormally);
  });
  test('nonfinite nutrition can never be persisted', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        oil.copyWith(carbsPer100g: value).validateMacroRanges,
        throwsArgumentError,
      );
      expect(
        oil.copyWith(proteinPer100g: value).validateMacroRanges,
        throwsArgumentError,
      );
    }
  });
  test('fiber cannot exceed total US carbohydrate', () {
    expect(
      oil.copyWith(fiberPer100g: 1).validateMacroRanges,
      throwsArgumentError,
    );
  });
}
