import 'package:flutter/material.dart';

import '../../../../low_treatment/presentation/formatters/low_treatment_context_formatters.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealLowTreatmentsSection extends StatelessWidget {
  const MealLowTreatmentsSection({super.key, required this.details});

  final MealDetailsData details;

  @override
  Widget build(BuildContext context) {
    if (details.lowTreatments.isEmpty) {
      return const SizedBox.shrink();
    }

    return MealSectionTile(
      title: 'Dosłodzenia',
      initiallyExpanded: true,
      children: [
        for (final treatment in details.lowTreatments)
          MealLowTreatmentTile(
            treatment: treatment,
            parentMealTime: details.meal.eatenOrPlannedAt,
          ),
      ],
    );
  }
}

class MealLowTreatmentTile extends StatelessWidget {
  const MealLowTreatmentTile({
    super.key,
    required this.treatment,
    required this.parentMealTime,
  });

  final MealLowTreatmentDetailsData treatment;
  final DateTime parentMealTime;

  @override
  Widget build(BuildContext context) {
    final lowTreatmentContext = treatment.context;
    final suggestedCarbs = lowTreatmentContext.suggestedCarbs;
    final suggestedWithinMinutes = lowTreatmentContext.suggestedWithinMinutes;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.bloodtype_outlined),
      title: Text(_timeLabel()),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                lowTreatmentReasonLabel(lowTreatmentContext.reason),
                lowTreatmentSourceLabel(lowTreatmentContext.source),
              ].join(' • '),
            ),
            const SizedBox(height: 4),
            Text(_ingredientsLabel()),
            const SizedBox(height: 4),
            Text(_amountLabel(suggestedCarbs, suggestedWithinMinutes)),
          ],
        ),
      ),
    );
  }

  String _timeLabel() {
    final treatmentTime = treatment.meal.eatenOrPlannedAt;
    final delay = treatmentTime.difference(parentMealTime);
    return '${mealTime(treatmentTime)} • ${formatDelayAfterMeal(delay)}';
  }

  String _ingredientsLabel() {
    if (treatment.ingredients.isEmpty) {
      return treatment.meal.name;
    }
    return treatment.ingredients
        .map((ingredient) {
          return '${ingredient.ingredientName}: ${formatGrams(ingredient.consumedTotalGrams)}';
        })
        .join(', ');
  }

  String _amountLabel(double? suggestedCarbs, int? suggestedWithinMinutes) {
    return [
      'Razem ${formatGrams(treatment.totalNetCarbsG)} netto',
      if (suggestedCarbs != null) 'sugestia ${formatGrams(suggestedCarbs)}',
      if (suggestedWithinMinutes != null && suggestedWithinMinutes > 0)
        'w $suggestedWithinMinutes min',
    ].join(' • ');
  }
}
