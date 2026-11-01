import 'package:flutter/material.dart';

import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../l10n/language.dart';
import 'meal_start_nutrition.dart';
import 'meal_start_plan.dart';

class MealStartSummary extends StatelessWidget {
  const MealStartSummary({
    super.key,
    required this.advice,
    required this.carbsGrams,
    required this.extendedCarbsGrams,
  });

  final MealAdvice advice;
  final double carbsGrams;
  final double extendedCarbsGrams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.mealStartPlanLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        MealStartPlan(advice: advice),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1),
        ),
        Text(
          context.lang.mealStartValuesLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        MealStartNutrition(
          carbsGrams: carbsGrams,
          extendedCarbsGrams: extendedCarbsGrams,
          scheduleSettings: advice.extendedCarbs.scheduleSettings,
        ),
      ],
    );
  }
}
