/// Resolves the multiplier used by the current ingredient amount editor.
/// Reference portions retain the existing 100 g conversion convention.
double? resolveIngredientGramsPerPortion({
  required bool usesGramAmount,
  required bool isReference,
  required double portionGrams,
  double? storedGramsPerPortion,
}) {
  if (usesGramAmount) {
    return 1;
  }
  if (isReference) {
    return 100;
  }
  if (portionGrams > 0) {
    return portionGrams;
  }
  return storedGramsPerPortion;
}

double? calculateIngredientTotalGrams({
  required double amount,
  required bool usesGramAmount,
  required double? gramsPerPortion,
}) {
  if (usesGramAmount) {
    return amount;
  }
  if (gramsPerPortion == null || gramsPerPortion <= 0) {
    return null;
  }
  return amount * gramsPerPortion;
}
