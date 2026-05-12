class IngredientScanResult {
  final String? name;
  final String? brand;
  final NutritionPer100g? nutritionPer100g;
  final List<RecognizedPortion> portions;

  const IngredientScanResult({
    required this.name,
    required this.brand,
    required this.nutritionPer100g,
    required this.portions,
  });

  bool get hasCompleteNutritionPer100g =>
      nutritionPer100g?.hasCompleteMacros ?? false;
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
