import '../../data/models/meal_summary_item.dart';

String formatMealSummaryAmount(double amount, String unitLabel) {
  final formattedAmount = amount % 1 == 0
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(1).replaceAll('.', ',');

  if (unitLabel == 'g') {
    return '${formattedAmount}g';
  }

  return '$formattedAmount $unitLabel';
}

String mealSummaryAmountLabel(MealSummaryItem item) {
  final portion = item.portion;
  if (portion == null) {
    return item.isReference ? 'porcji referencyjnych' : 'g';
  }
  return portion.name;
}
