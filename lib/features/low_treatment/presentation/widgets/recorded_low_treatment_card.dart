import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/nutrition_summary_metric.dart';
import '../../domain/models/recorded_low_treatment.dart';
import '../formatters/low_treatment_context_formatters.dart';

/// Inline historical consumption; a low treatment has no meal-detail route.
class RecordedLowTreatmentCard extends StatelessWidget {
  const RecordedLowTreatmentCard({super.key, required this.treatment});
  final RecordedLowTreatment treatment;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DateFormat(
              'd.MM HH:mm',
              lang.localeName,
            ).format(treatment.eatenAt.toLocal()),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          NutritionSummaryMetric(
            label: lang.beforeMealCarbs,
            value: treatment.netCarbsGrams == null
                ? lang.beforeMealUnknownMacros
                : '${number.format(treatment.netCarbsGrams)} g',
            icon: Icons.cake_outlined,
            color: colors.tertiary,
          ),
          for (final ingredient in treatment.ingredients)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(ingredient.name)),
                  const SizedBox(width: 12),
                  Text(
                    '${number.format(ingredient.grams)} g',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          if (treatment.reason != null) ...[
            const SizedBox(height: 8),
            Text(
              lowTreatmentReasonLabel(treatment.reason!, lang),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (treatment.suggestedCarbs != null) ...[
            const SizedBox(height: 4),
            Text(
              lang.lowTreatmentSuggestionInline(
                '${number.format(treatment.suggestedCarbs)} g',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
