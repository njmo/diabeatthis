import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/macronutrient_proportions.dart';
import '../../../../common/widgets/nutrition_metric_tile.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../domain/use_cases/calculate_ingredient_review_use_case.dart';

class MealIngredientReviewNutrition extends StatelessWidget {
  const MealIngredientReviewNutrition({
    super.key,
    required this.ingredient,
    required this.totalGrams,
  });

  final IngredientDraft ingredient;
  final double? totalGrams;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final nutrition = const CalculateIngredientReviewUseCase()(
      ingredient,
      totalGrams ?? 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveMetricList(
          maxColumns: 2,
          spacing: 8,
          runSpacing: 8,
          children: [
            NutritionMetricTile(
              icon: Icons.grain,
              label: lang.mealCarbsLabel,
              accentColor: Colors.blue,
              emphasized: true,
              value: totalGrams == null ? '–' : '${nutrition.carbs.ceil()} g',
            ),
            NutritionMetricTile(
              icon: Icons.schedule_outlined,
              label: lang.mealStartEcarbsLabel,
              accentColor: Colors.deepPurple,
              emphasized: true,
              value: totalGrams == null ? '–' : '${nutrition.extendedCarbs} g',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (totalGrams != null)
          MacronutrientProportions(
            fatBeforeProtein: true,
            carbsGrams: nutrition.carbs,
            proteinGrams: nutrition.protein,
            fatGrams: nutrition.fat,
          ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                totalGrams == null ? '–' : '${nutrition.calories.round()} kcal',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              Text(lang.mealCaloriesLabel, textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}
