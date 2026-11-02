import 'dart:math' as math;

import '../../domain/utils/meal_completion_amounts.dart';
import '../models/meal_completion_choice.dart';
import '../models/meal_summary_draft.dart';

MealSummaryDraft prepareMealAddOnDraft(
  MealSummaryDraft draft, {
  double? totalMultiplier,
}) {
  return draft.copyWith(
    extraItems: [],
    itemsById: {
      for (final entry in draft.itemsById.entries)
        entry.key: entry.value.copyWith(
          consumedAmount: totalMultiplier == null || entry.value.isExtra
              ? entry.value.reportedAmount
              : math.max(
                  entry.value.reportedAmount,
                  entry.value.plannedAmount * totalMultiplier,
                ),
          consumedConfidence:
              totalMultiplier != null &&
                  !entry.value.isExtra &&
                  entry.value.plannedAmount * totalMultiplier >
                      entry.value.reportedAmount + 0.001
              ? 0.75
              : entry.value.consumedConfidence,
        ),
    },
  );
}

bool mealAddOnAmountsValid(MealSummaryDraft draft) =>
    mealCompletionAmountsValid(draft, MealCompletionChoice.more) &&
    draft.itemsById.values.every(
      (item) => item.consumedAmount >= item.reportedAmount,
    );
