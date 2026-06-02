import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../models/meal_summary_draft.dart';

class MealSummaryAapsCarbs {
  const MealSummaryAapsCarbs({
    required this.carbs,
    required this.extendedCarbs,
  });

  final int carbs;
  final int extendedCarbs;
}

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

  int get roundedTotal => total.ceil();
  int get roundedItemAmountDelta => itemAmountDelta.ceil();
  int get roundedExtraItemsCarbs => extraItemsCarbs.ceil();

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

MealSummaryAapsCarbs calculateMealSummaryAapsCarbs(MealSummaryDraft draft) {
  final delta = calculateMealSummaryCarbsDelta(draft);

  final extraItemsMacros = draft.extraItems.fold(
    (fatGrams: 0.0, proteinGrams: 0.0),
    (sum, item) {
      final grams = calculateMealIngredientDraftGrams(item);
      return (
        fatGrams: sum.fatGrams + grams * item.ingredient.fatPer100g / 100,
        proteinGrams:
            sum.proteinGrams + grams * item.ingredient.proteinPer100g / 100,
      );
    },
  );

  final extendedCarbs = const WbtExtendedCarbsCalculator().calculateFromMacros(
    fatGrams: extraItemsMacros.fatGrams,
    proteinGrams: extraItemsMacros.proteinGrams,
  );

  return MealSummaryAapsCarbs(
    carbs: delta.roundedTotal,
    extendedCarbs: extendedCarbs.grams,
  );
}

double calculateExtraItemNetCarbs(MealIngredientsDraft item) {
  final grams = calculateMealIngredientDraftGrams(item);

  return calculateNetCarbs(
    carbs: grams * item.ingredient.carbsPer100g / 100,
    fiber: grams * item.ingredient.fiberPer100g / 100,
    labelMode: item.ingredient.carbsLabelMode,
  );
}

double calculateMealIngredientDraftGrams(MealIngredientsDraft item) {
  return item.ingredient.isReference
      ? item.amount * 100
      : item.ingredientPortion.portion.map(
          empty: (_) => item.amount,
          existing: (_) => item.amount * item.ingredientPortion.amount,
          draft: (_) => item.amount * item.ingredientPortion.amount,
        );
}
