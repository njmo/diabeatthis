import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../domain/utils/ingredient_barcode_validator.dart';
import 'ingredient_draft.dart';

extension IngredientDraftValidation on IngredientDraft {
  static const _barcodeValidator = IngredientBarcodeValidator();
  static const maxMacroPer100g = 100.0;

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
        carbsPer100g <= maxMacroPer100g &&
        fatPer100g >= 0 &&
        fatPer100g <= maxMacroPer100g &&
        fiber >= 0 &&
        fiber <= maxMacroPer100g &&
        proteinPer100g >= 0 &&
        proteinPer100g <= maxMacroPer100g &&
        hasPositiveNonEuNetCarbs;
  }

  bool get hasValidBarcode {
    final normalized = normalizedBarcode;
    if (normalized == null || normalized.isEmpty) {
      return true;
    }
    return _barcodeValidator.normalizeValidBarcode(normalized) != null;
  }

  String? get normalizedBarcode {
    final normalized = barcode?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void validateMacroRanges() {
    if (carbsPer100g < 0 ||
        fatPer100g < 0 ||
        fiberPer100g < 0 ||
        proteinPer100g < 0) {
      throw ArgumentError('Ingredient macros cannot be negative');
    }
    if (carbsPer100g > maxMacroPer100g ||
        fatPer100g > maxMacroPer100g ||
        fiberPer100g > maxMacroPer100g ||
        proteinPer100g > maxMacroPer100g) {
      throw ArgumentError('Ingredient macros cannot exceed 100g per 100g');
    }
    if (!hasPositiveNonEuNetCarbs) {
      throw ArgumentError(
        'Dla non-UE węglowodany muszą być większe niż błonnik.',
      );
    }
  }

  void validateBarcode() {
    if (!hasValidBarcode) {
      throw ArgumentError('Ingredient barcode must be a valid EAN/UPC/GTIN');
    }
  }
}
