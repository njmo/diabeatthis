import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/nutrition/meal_nutrition_totals.dart';
import '../../../../../common/widgets/nutrition_summary_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';

class MealPortionMacros extends StatelessWidget {
  final MealNutritionTotals nutrition;
  const MealPortionMacros({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final colors = Theme.of(context).colorScheme;
    final number = NumberFormat('0.#', lang.localeName);
    return ResponsiveMetricList(
      minimumWidth: 110,
      maxColumns: 2,
      children: [
        NutritionSummaryMetric(
          label: lang.mealCarbsLabel,
          icon: Icons.grass_outlined,
          color: colors.primary,
          value: '${number.format(nutrition.totalCarbsG)} g',
        ),
        NutritionSummaryMetric(
          label: lang.mealProteinLabel,
          icon: Icons.egg_outlined,
          color: colors.secondary,
          value: '${number.format(nutrition.totalProteinG)} g',
        ),
        NutritionSummaryMetric(
          label: lang.mealFatLabel,
          icon: Icons.opacity,
          color: colors.tertiary,
          value: '${number.format(nutrition.totalFatG)} g',
        ),
        NutritionSummaryMetric(
          label: lang.mealCaloriesLabel,
          icon: Icons.local_fire_department_outlined,
          color: colors.tertiary,
          value: '${number.format(nutrition.totalCaloriesKcal)} kcal',
        ),
      ],
    );
  }
}
