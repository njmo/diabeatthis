import 'dart:math' as math;

import '../../../../common/meal/meal_extended_carbs.dart';
import '../models/meal_summary_draft.dart';
import 'meal_summary_carbs_delta.dart';
import 'meal_summary_nutrition_comparison.dart';

/// Additional amounts for the completion flow, relative to the last report.
MealSummaryAapsCarbs calculateMealCompletionAapsCarbs(MealSummaryDraft draft) {
  final reported = draft.copyWith(
    itemsById: {
      for (final entry in draft.itemsById.entries)
        entry.key: entry.value.copyWith(
          consumedAmount: entry.value.reportedAmount,
        ),
    },
    extraItems: [],
  );
  final consumedExtendedCarbs = mealExtendedCarbsFromMacros(
    mealSummaryNutritionTotals(draft, planned: false),
  );
  final reportedExtendedCarbs = mealExtendedCarbsFromMacros(
    mealSummaryNutritionTotals(reported, planned: false),
  );
  return MealSummaryAapsCarbs(
    carbs: math.max(0, calculateMealSummaryCarbsDelta(draft).roundedTotal),
    extendedCarbs: math.max(0, consumedExtendedCarbs - reportedExtendedCarbs),
  );
}
