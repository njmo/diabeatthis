import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/nutrition/meal_nutrition_totals.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import 'meal_detail_formatters.dart';

class MealMacroStrip extends StatelessWidget {
  final MealNutritionTotals nutrition;

  const MealMacroStrip({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = {
      context.lang.mealCarbsLabel: nutrition.totalCarbsG,
      context.lang.mealProteinLabel: nutrition.totalProteinG,
      context.lang.mealFatLabel: nutrition.totalFatG,
    };
    return ResponsiveMetricList(
      minimumWidth: 80,
      children: [
        for (final entry in values.entries)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatGrams(entry.value),
                style: theme.textTheme.titleMedium,
              ),
              Text(
                entry.key,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
