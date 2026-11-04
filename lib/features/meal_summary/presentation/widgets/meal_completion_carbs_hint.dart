import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/stable_macro_ceil.dart';
import '../models/meal_summary_draft.dart';
import '../utils/meal_completion_shortfall.dart';
import '../utils/meal_summary_carbs_delta.dart';
import 'meal_summary_carbs_hint_card.dart';

class MealCompletionCarbsHint extends StatelessWidget {
  const MealCompletionCarbsHint({
    super.key,
    required this.draft,
    this.hasRecordedBolus = false,
    this.requiresBolus = false,
    this.coveredNetCarbs,
  });

  final MealSummaryDraft draft;
  final bool hasRecordedBolus;
  final bool requiresBolus;
  final double? coveredNetCarbs;

  @override
  Widget build(BuildContext context) {
    final shortfall = mealCompletionNeedsShortfallReview(
      draft,
      hasRecordedBolus: hasRecordedBolus,
      coveredNetCarbs: coveredNetCarbs,
    );
    if (!requiresBolus &&
        coveredNetCarbs == null &&
        draft.mealStatus != 'eating-then-bolus' &&
        hasRecordedBolus &&
        !shortfall) {
      return MealSummaryCarbsHintCard(
        draft: draft,
        addOnAlreadyReported: calculateMealSummaryCarbsDelta(
          draft,
        ).usesReportedBaseline,
      );
    }
    final actual = calculateMealSummaryConsumedCarbs(draft);
    final planned = draft.itemsById.values.fold(
      0.0,
      (sum, item) => sum + item.plannedAmount * item.netCarbsPerAmount,
    );
    final delta = (actual - planned).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.lang.mealCompletionActualCarbs(actual.ceilMacro())),
            if (delta != 0) ...[
              const SizedBox(height: 4),
              Text(
                delta < 0
                    ? context.lang.mealCompletionCarbsBelowPlan(delta.abs())
                    : context.lang.mealCompletionCarbsAbovePlan(delta),
              ),
            ],
            if (shortfall) ...[
              const SizedBox(height: 8),
              Text(context.lang.mealCompletionShortfallNotice),
            ],
          ],
        ),
      ),
    );
  }
}
