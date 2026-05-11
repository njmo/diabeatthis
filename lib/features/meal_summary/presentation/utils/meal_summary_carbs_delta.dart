import '../../../meals/data/drafts/meal_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../models/meal_summary_draft.dart';

class MealSummaryCarbsDelta {
  const MealSummaryCarbsDelta({
    required this.itemAmountDelta,
    required this.extraItemsCarbs,
    required this.usesReportedBaseline,
  });

  final double itemAmountDelta;
  final double extraItemsCarbs;
  final bool usesReportedBaseline;

  double get total => itemAmountDelta + extraItemsCarbs;

  int get roundedTotal => total.round();
  int get roundedItemAmountDelta => itemAmountDelta.round();
  int get roundedExtraItemsCarbs => extraItemsCarbs.round();

  bool get isNeutral => total.abs() < 0.5;
  bool get isPositive => total >= 0.5;
  bool get isNegative => total <= -0.5;
}

MealSummaryCarbsDelta calculateMealSummaryCarbsDelta(MealSummaryDraft draft) {
  var usesReportedBaseline = false;
  final itemAmountDelta = draft.itemsById.values.fold(0.0, (sum, item) {
    if ((item.reportedAmount - item.plannedAmount).abs() >= 0.01) {
      usesReportedBaseline = true;
    }
    final amountDelta = item.consumedAmount - item.reportedAmount;
    return sum + amountDelta * item.netCarbsPerAmount;
  });

  final extraItemsCarbs = draft.extraItems.fold(0.0, (sum, item) {
    return sum + calculateExtraItemNetCarbs(item);
  });

  return MealSummaryCarbsDelta(
    itemAmountDelta: itemAmountDelta,
    extraItemsCarbs: extraItemsCarbs,
    usesReportedBaseline: usesReportedBaseline,
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
