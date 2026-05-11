import 'package:flutter/material.dart';

import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealAdvisorResultSection extends StatelessWidget {
  final MealDetailsData details;

  const MealAdvisorResultSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final decision = details.advisorDecision;

    return MealSectionTile(
      title: 'Decyzja Meal Advisora',
      children: [
        if (decision == null)
          const MealInfoRow(label: 'Wynik', value: '-')
        else ...[
          MealInfoRow(label: 'Wynik', value: decision.result),
          MealInfoRow(
            label: 'Początkowe czekanie',
            value: '${decision.initialWaitTime} min',
          ),
          MealInfoRow(
            label: 'Finalne czekanie',
            value: '${decision.finalWaitTime} min',
          ),
          MealInfoRow(
            label: 'Czekanie pominięte',
            value: decision.waitTimeIgnored ? 'tak' : 'nie',
          ),
          MealInfoRow(
            label: 'Powód decyzji',
            value: fallbackText(decision.decisionReason),
          ),
          MealInfoRow(label: 'Wersja', value: decision.version.toString()),
          MealInfoRow(
            label: 'Utworzono',
            value: mealDateTime(decision.createdAt),
          ),
          MealInfoRow(
            label: 'Zaktualizowano',
            value: mealDateTime(decision.updatedAt),
          ),
        ],
      ],
    );
  }
}
