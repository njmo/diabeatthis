import '../../../../core/domain/model/carbs_label_mode.dart';
import 'ingredient_draft.dart';

extension IngredientDraftValidation on IngredientDraft {
  bool get hasEnergyMacros =>
      carbsPer100g > 0 || fatPer100g > 0 || proteinPer100g > 0;

  bool get hasPositiveNonEuNetCarbs {
    if (carbsLabelMode != CarbsLabelMode.nonEu) {
      return true;
    }
    final fiber = isReference ? 0.0 : fiberPer100g;
    return carbsPer100g - fiber > 0;
  }

  bool get hasValidMacroRanges {
    final fiber = isReference ? 0.0 : fiberPer100g;
    return carbsPer100g >= 0 &&
        fatPer100g >= 0 &&
        fiber >= 0 &&
        proteinPer100g >= 0 &&
        hasPositiveNonEuNetCarbs;
  }

  void validateMacroRanges() {
    if (carbsPer100g < 0 ||
        fatPer100g < 0 ||
        fiberPer100g < 0 ||
        proteinPer100g < 0) {
      throw ArgumentError('Ingredient macros cannot be negative');
    }
    if (!hasPositiveNonEuNetCarbs) {
      throw ArgumentError(
        'Dla non-UE węglowodany muszą być większe niż błonnik.',
      );
    }
  }
}
