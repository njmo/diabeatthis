import 'dart:math' as math;

import '../../../../common/nutrition/stable_macro_ceil.dart';
import '../models/meal_summary_draft.dart';
import 'meal_completion_aaps_carbs.dart';
import 'meal_summary_aaps_suggestion.dart';
import 'meal_summary_carbs_delta.dart';

DateTime mealCompletionEndForSave({
  required DateTime confirmedEndedAt,
  required bool finishedRefill,
  required DateTime now,
}) => finishedRefill ? now : confirmedEndedAt;

bool mealCompletionNeedsShortfallReview(
  MealSummaryDraft draft, {
  required bool hasRecordedBolus,
  double? coveredNetCarbs,
}) =>
    hasRecordedBolus &&
    (coveredNetCarbs != null || draft.mealStatus != 'eating-then-bolus') &&
    mealCompletionShortfallCarbs(draft, coveredNetCarbs: coveredNetCarbs) >=
        0.5;

double mealCompletionShortfallCarbs(
  MealSummaryDraft draft, {
  double? coveredNetCarbs,
}) => math.max(
  0.0,
  coveredNetCarbs == null
      ? -calculateMealSummaryCarbsDelta(draft).total
      // AAPS receives whole grams rounded up. A fully eaten 49.1 g meal
      // therefore matches its confirmed 50 g request without a shortfall.
      : stableMacroDifference(
          coveredNetCarbs,
          calculateMealSummaryConsumedCarbs(draft).ceilMacro(),
        ),
);

/// Automatic suggestions never include a negative carbohydrate correction.
/// Corrections require a separate, explicit choice in the completion review.
bool mealCompletionCanOpenAapsSuggestion(
  MealSummaryDraft draft, {
  required bool hasRecordedBolus,
}) =>
    hasRecordedBolus &&
    !calculateMealSummaryCarbsDelta(draft).isNegative &&
    shouldOpenAapsForMealSummaryAapsCarbs(
      calculateMealCompletionAapsCarbs(draft),
    );
