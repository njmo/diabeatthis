import 'package:flutter/material.dart';

import '../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../l10n/language.dart';
import '../nutrition_summary_metric.dart';
import '../responsive_metric_list.dart';
import 'meal_start_schedule.dart';

class MealStartNutrition extends StatelessWidget {
  const MealStartNutrition({
    super.key,
    required this.carbsGrams,
    required this.extendedCarbsGrams,
    required this.scheduleSettings,
    this.deferExtendedCarbs = false,
  });

  final double carbsGrams;
  final double extendedCarbsGrams;
  final ExtendedCarbsScheduleSettings scheduleSettings;
  final bool deferExtendedCarbs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveMetricList(
          maxColumns: 2,
          spacing: 12,
          runSpacing: 12,
          children: [
            NutritionSummaryMetric(
              label: context.lang.mealCarbsLabel,
              value: context.lang.mealStartGrams(carbsGrams.ceil()),
              icon: Icons.grass_rounded,
              color: colors.primary,
            ),
            NutritionSummaryMetric(
              label: context.lang.mealStartEcarbsLabel,
              value: context.lang.mealStartGrams(extendedCarbsGrams.ceil()),
              icon: Icons.history_rounded,
              color: colors.primary,
            ),
          ],
        ),
        if (deferExtendedCarbs) ...[
          const SizedBox(height: 10),
          Text(context.lang.mealStartDeferredEcarbs),
        ] else if (extendedCarbsGrams > 0) ...[
          const SizedBox(height: 10),
          MealStartSchedule(
            grams: extendedCarbsGrams.ceil(),
            settings: scheduleSettings,
          ),
        ],
      ],
    );
  }
}
