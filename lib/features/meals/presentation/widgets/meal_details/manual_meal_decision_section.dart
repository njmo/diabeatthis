import 'package:flutter/material.dart';

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
      title: 'Decyzja ręczna',
      children: [
        MealInfoRow(
          label: 'Wybrany przebieg',
          value: mealDecisionLabel(choice),
        ),
        if (details.plannedSnapshot != null &&
            details.consumedSnapshot != null &&
            details.meal.status == 'summarized' &&
            details.hasConsumedPlannedAmounts)
          const MealInfoRow(
            label: 'Podsumowanie',
            value: 'Zjedzono całość · bez dokładki',
          ),
        if (start != null)
          MealInfoRow(label: 'Początek jedzenia', value: mealDateTime(start)),
        MealInfoRow(
          label: 'Czas jedzenia',
          value: start != null && end != null
              ? '${end.difference(start).inMinutes} min'
              : 'Brak danych',
        ),
        if (end != null)
          MealInfoRow(label: 'Koniec jedzenia', value: mealDateTime(end)),
        if (choice == MealDecision.bolusWaitThenEat) ...[
          if (actualWait == null)
            MealInfoRow(
              label: 'Wybrany czas czekania',
              value: '${decision.initialWaitTime} min',
            ),
          MealInfoRow(
            label: 'Czas czekania',
            value: actualWait == null ? 'Brak danych' : '$actualWait min',
          ),
        ],
        MealInfoRow(
          label: 'Decyzja podjęta',
          value: mealDateTime(decision.createdAt),
        ),
      ],
    );
  }
}
