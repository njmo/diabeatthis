import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/manual_meal_decision.dart';
import '../../../../../common/meal/meal_decision.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class ManualMealDecisionSection extends StatelessWidget {
  final MealDetailsData details;
  const ManualMealDecisionSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final decision = details.advisorDecision!;
    final start = details.recordedEatingStartedAt;
    final end = details.recordedEatingEndedAt;
    final choice = manualMealDecisionFromHistory(
      details.statusHistory.map((event) => event.status),
      selectedWaitMinutes: decision.initialWaitTime,
    );
    final actualWait = details.recordedWait?.inMinutes;
    return MealSectionTile(
      title: context.lang.uiManualDecision,
      children: [
        MealInfoRow(
          label: context.lang.uiSelectedSequence,
          value: mealDecisionLabel(choice),
        ),
        if (details.plannedSnapshot != null &&
            details.consumedSnapshot != null &&
            details.meal.status == 'summarized' &&
            details.hasConsumedPlannedAmounts)
          MealInfoRow(
            label: context.lang.addIngredientSummaryTitle,
            value: context.lang.uiAllEatenNoExtraFood,
          ),
        if (start != null)
          MealInfoRow(
            label: context.lang.uiEatingStarted,
            value: mealDateTime(start),
          ),
        MealInfoRow(
          label: context.lang.uiEatingDuration,
          value: start != null && end != null
              ? '${end.difference(start).inMinutes} min'
              : context.lang.beforeMealUnavailable,
        ),
        if (end != null)
          MealInfoRow(
            label: context.lang.mealEatingEnd,
            value: mealDateTime(end),
          ),
        if (choice == MealDecision.bolusWaitThenEat) ...[
          if (actualWait == null)
            MealInfoRow(
              label: context.lang.uiSelectedWaitingTime,
              value: '${decision.initialWaitTime} min',
            ),
          MealInfoRow(
            label: context.lang.uiWaitingTime,
            value: actualWait == null
                ? context.lang.beforeMealUnavailable
                : '$actualWait min',
          ),
        ],
        MealInfoRow(
          label: context.lang.uiDecisionMade,
          value: mealDateTime(decision.createdAt),
        ),
      ],
    );
  }
}
