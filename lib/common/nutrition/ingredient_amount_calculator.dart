import 'ingredient_amount_kind.dart';

/// Resolves the multiplier used by the current ingredient amount editor.
/// Reference portions retain the existing 100 g conversion convention.
double? resolveIngredientGramsPerPortion({
  required IngredientAmountKind kind,
  required double portionGrams,
  double? storedGramsPerPortion,
}) {
  return switch (kind) {
    IngredientAmountKind.grams => 1,
    IngredientAmountKind.referencePortion => 100,
    IngredientAmountKind.portion =>
      portionGrams > 0 ? portionGrams : storedGramsPerPortion,
  };
}

double? calculateIngredientTotalGrams({
  required double amount,
  required IngredientAmountKind kind,
  required double? gramsPerPortion,
}) {
  if (kind == IngredientAmountKind.grams) {
    return amount;
  }
  if (gramsPerPortion == null || gramsPerPortion <= 0) {
    return null;
  }
  return amount * gramsPerPortion;
}
