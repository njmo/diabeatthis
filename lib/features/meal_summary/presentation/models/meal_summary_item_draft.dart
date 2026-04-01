class MealSummaryItemDraft {
  final int mealIngredientId;
  final String name;

  final double plannedAmount;
  final String amountLabel;

  final double consumedAmount;
  final double consumedConfidence;

  const MealSummaryItemDraft({
    required this.name,
    required this.mealIngredientId,
    required this.plannedAmount,
    required this.amountLabel,
    required this.consumedAmount,
    required this.consumedConfidence,
  });

  MealSummaryItemDraft copyWith({
    double? consumedAmount,
    double? consumedConfidence,
  }) {
    return MealSummaryItemDraft(
      name: name,
      mealIngredientId: mealIngredientId,
      plannedAmount: plannedAmount,
      amountLabel: amountLabel,
      consumedAmount: consumedAmount ?? this.consumedAmount,
      consumedConfidence: consumedConfidence ?? this.consumedConfidence,
    );
  }
}
