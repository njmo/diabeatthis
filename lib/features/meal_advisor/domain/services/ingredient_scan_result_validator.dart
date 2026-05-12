import '../../data/models/ingredient_scan_result.dart';

class IngredientScanResultValidator {
  const IngredientScanResultValidator();

  IngredientScanResult validate(IngredientScanResult result) {
    if (result.status != IngredientScanStatus.recognized ||
        result.hasRecognizedMinimumData) {
      return result;
    }

    return IngredientScanResult(
      status: IngredientScanStatus.needsReview,
      name: result.name,
      brand: result.brand,
      nutritionPer100g: result.nutritionPer100g,
      portions: result.portions,
      retakeRequest: result.retakeRequest,
    );
  }
}
