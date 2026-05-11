import '../../../meals/data/drafts/meal_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../models/meal_summary_draft.dart';

class MealSummaryCarbsDelta {
  const MealSummaryCarbsDelta({
    required this.plannedItemsDelta,
    required this.extraItemsCarbs,
  });

  final double plannedItemsDelta;
  final double extraItemsCarbs;

  double get total => plannedItemsDelta + extraItemsCarbs;

  int get roundedTotal => total.round();
  int get roundedPlannedItemsDelta => plannedItemsDelta.round();
  int get roundedExtraItemsCarbs => extraItemsCarbs.round();

  bool get isNeutral => total.abs() < 0.5;
  bool get isPositive => total >= 0.5;
  bool get isNegative => total <= -0.5;
}

MealSummaryCarbsDelta calculateMealSummaryCarbsDelta(MealSummaryDraft draft) {
  final plannedItemsDelta = draft.itemsById.values.fold(0.0, (sum, item) {
    final amountDelta = item.consumedAmount - item.plannedAmount;
    return sum + amountDelta * item.netCarbsPerAmount;
  });

  final extraItemsCarbs = draft.extraItems.fold(0.0, (sum, item) {
    return sum + calculateExtraItemNetCarbs(item);
  });

  return MealSummaryCarbsDelta(
    plannedItemsDelta: plannedItemsDelta,
    extraItemsCarbs: extraItemsCarbs,
  );
}

double calculateExtraItemNetCarbs(MealIngredientsDraft item) {
  final netCarbsPer100g =
      item.ingredient.carbsPer100g - item.ingredient.fiberPer100g;
  final safeNetCarbsPer100g = netCarbsPer100g < 0
      ? 0.0
      : netCarbsPer100g.toDouble();
  final grams = item.ingredient.isReference
      ? item.amount * 100
      : item.ingredientPortion.portion.map(
          empty: (_) => item.amount,
          existing: (_) => item.amount * item.ingredientPortion.amount,
          draft: (_) => item.amount * item.ingredientPortion.amount,
        );

  return grams * safeNetCarbsPer100g / 100;
}
