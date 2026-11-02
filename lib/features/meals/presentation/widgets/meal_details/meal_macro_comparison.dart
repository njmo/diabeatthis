import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/nutrition/meal_nutrition_totals.dart';
import '../../../../../common/widgets/plan_actual_meter.dart';
import '../../../domain/use_cases/build_meal_portion_use_case.dart';

class MealMacroComparison extends StatelessWidget {
  const MealMacroComparison({
    super.key,
    required this.planned,
    required this.consumed,
  });
  final MealNutritionTotals planned;
  final MealNutritionTotals consumed;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.#', lang.localeName);
    final rows = [
      (lang.mealCarbsLabel, planned.totalCarbsG, consumed.totalCarbsG, 'g'),
      (
        lang.mealProteinLabel,
        planned.totalProteinG,
        consumed.totalProteinG,
        'g',
      ),
      (lang.mealFatLabel, planned.totalFatG, consumed.totalFatG, 'g'),
      (lang.mealFiberLabel, planned.totalFiberG, consumed.totalFiberG, 'g'),
      (
        lang.mealCaloriesLabel,
        planned.totalCaloriesKcal,
        consumed.totalCaloriesKcal,
        'kcal',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, plan, actual, unit) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(label),
                    Text(
                      '${number.format(actual)} $unit',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (!mealPortionAmountsMatch(plan, actual)) ...[
                  PlanActualMeter(
                    planned: plan,
                    actual: actual,
                    semanticLabel:
                        '$label: ${lang.mealConsumedInline('${number.format(actual)} $unit')}, ${lang.mealPlanInline('${number.format(plan)} $unit')}',
                  ),
                  Text(
                    lang.mealPlanInline('${number.format(plan)} $unit'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
