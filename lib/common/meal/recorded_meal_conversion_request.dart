/// A missing historical factor and an explicitly labelled current suggestion.
class RecordedMealConversionRequest {
  final int entryId;
  final int mealId;
  final int ingredientId;
  final int portionId;
  final String ingredientName;
  final String portionName;
  final double? currentGrams;

  const RecordedMealConversionRequest({
    required this.entryId,
    required this.mealId,
    required this.ingredientId,
    required this.portionId,
    required this.ingredientName,
    required this.portionName,
    required this.currentGrams,
  });
}
