class MealSummaryItemDraft {
  final int mealIngredientId;
  final String name;

  final double plannedAmount;
  final double reportedAmount;
  final String amountLabel;
  final double netCarbsPerAmount;

  final double consumedAmount;
  final double consumedConfidence;
  final double? gramsPerAmount;
  final bool isExtra;
  final double? carbsPerAmount;
  final double fatPerAmount;
  final double proteinPerAmount;
  final double fiberPerAmount;

  const MealSummaryItemDraft({
    required this.name,
    required this.mealIngredientId,
    required this.plannedAmount,
    required this.reportedAmount,
    required this.amountLabel,
    required this.netCarbsPerAmount,
    required this.consumedAmount,
    required this.consumedConfidence,
    this.gramsPerAmount,
    this.isExtra = false,
    this.carbsPerAmount,
    this.fatPerAmount = 0,
    this.proteinPerAmount = 0,
    this.fiberPerAmount = 0,
  });

  MealSummaryItemDraft copyWith({
    double? consumedAmount,
    double? consumedConfidence,
  }) {
    return MealSummaryItemDraft(
      name: name,
      mealIngredientId: mealIngredientId,
      plannedAmount: plannedAmount,
      reportedAmount: reportedAmount,
      amountLabel: amountLabel,
      netCarbsPerAmount: netCarbsPerAmount,
      consumedAmount: consumedAmount ?? this.consumedAmount,
      consumedConfidence: consumedConfidence ?? this.consumedConfidence,
      gramsPerAmount: gramsPerAmount,
      isExtra: isExtra,
      carbsPerAmount: carbsPerAmount,
      fatPerAmount: fatPerAmount,
      proteinPerAmount: proteinPerAmount,
      fiberPerAmount: fiberPerAmount,
    );
  }
}
