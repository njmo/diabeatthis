enum IngredientScanStatus { recognized, needsRetake, needsReview }

enum IngredientScanPhotoTarget { front, nutritionLabel, both }

class IngredientScanResult {
  final IngredientScanStatus status;
  final String? name;
  final String? brand;
  final NutritionPer100g? nutritionPer100g;
  final List<RecognizedPortion> portions;
  final IngredientScanRetakeRequest? retakeRequest;

  const IngredientScanResult({
    required this.status,
    required this.name,
    required this.brand,
    required this.nutritionPer100g,
    required this.portions,
    required this.retakeRequest,
  });

  bool get needsRetake => status == IngredientScanStatus.needsRetake;
  bool get needsReview => status == IngredientScanStatus.needsReview;
  bool get hasRecognizedMinimumData =>
      name != null && hasCompleteNutritionPer100g;

  bool get hasCompleteNutritionPer100g =>
      nutritionPer100g?.hasCompleteMacros ?? false;
}

class IngredientScanRetakeRequest {
  final IngredientScanPhotoTarget photo;
  final String? reason;
  final String? message;

  const IngredientScanRetakeRequest({
    required this.photo,
    required this.reason,
    required this.message,
  });
}

class NutritionPer100g {
  final double? carbs;
  final double? fat;
  final double? protein;
  final double? fiber;

  const NutritionPer100g({
    required this.carbs,
    required this.fat,
    required this.protein,
    required this.fiber,
  });

  bool get hasCompleteMacros =>
      carbs != null && fat != null && protein != null && fiber != null;
}

class RecognizedPortion {
  final String? name;
  final String? unitHint;
  final double? grams;
  final String? source;

  const RecognizedPortion({
    required this.name,
    required this.unitHint,
    required this.grams,
    required this.source,
  });
}
