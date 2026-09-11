/// Ingredient identity and mass, independent of portion size.
class MealComposition {
  final Map<int, double> grams;
  MealComposition(Map<int, double> grams) : grams = Map.unmodifiable(grams);
  double get totalGrams => grams.values.fold(0.0, (a, b) => a + b);
  bool get isValid =>
      grams.isNotEmpty &&
      grams.values.every((g) => g.isFinite && g > 0) &&
      totalGrams.isFinite;

  /// Total variation of mass shares. Missing ingredients count as zero.
  double? distanceTo(MealComposition other) {
    if (!isValid || !other.isValid) return null;
    final total = totalGrams;
    final otherTotal = other.totalGrams;
    return {...grams.keys, ...other.grams.keys}.fold(
          0.0,
          (sum, id) =>
              sum +
              ((grams[id] ?? 0) / total - (other.grams[id] ?? 0) / otherTotal)
                  .abs(),
        ) /
        2;
  }
}
