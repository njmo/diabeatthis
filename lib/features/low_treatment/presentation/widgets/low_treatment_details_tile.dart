import 'package:flutter/material.dart';

import '../../../meals/data/models/meal_details_data.dart';
import '../../../meals/presentation/widgets/meal_details/meal_detail_formatters.dart';
import '../formatters/low_treatment_context_formatters.dart';

class LowTreatmentDetailsTile extends StatelessWidget {
  const LowTreatmentDetailsTile({
    super.key,
    required this.treatment,
    required this.timeLabel,
    this.contentPadding,
  });

  final MealLowTreatmentDetailsData treatment;
  final String timeLabel;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final lowTreatmentContext = treatment.context;
    final suggestedCarbs = lowTreatmentContext.suggestedCarbs;
    final suggestedWithinMinutes = lowTreatmentContext.suggestedWithinMinutes;

    return ListTile(
      contentPadding: contentPadding,
      leading: const Icon(Icons.bloodtype_outlined),
      title: Text(timeLabel),
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
