import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/macronutrient_proportions.dart';
import '../../../../../common/widgets/nutrition_summary_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../../../core/domain/model/meal_macro_summary.dart';
import '../../../data/providers/meal_ingredients_list_provider.dart';

class MealReviewNutrition extends ConsumerWidget {
  const MealReviewNutrition({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref
        .watch(calculatedMacronutrientsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Text(context.lang.mealIngredientsLoadError(error)),
          data: (macros) {
            final summary = MealMacroSummary(
              carbsGrams: macros.carbsTotal.toDouble(),
              fatGrams: macros.fatTotal.toDouble(),
              proteinGrams: macros.proteinTotal.toDouble(),
              fiberGrams: macros.fiberTotal.toDouble(),
              netCarbsGrams: macros.netCarbsTotal.toDouble(),
              totalGrams: 0,
            );
            final nutrients = {
              context.lang.mealFiberLabel: '${macros.fiberTotal} g',
              context.lang.mealCaloriesLabel:
                  '${summary.totalKcal.round()} kcal',
            };
            return Card.outlined(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.lang.mealFlowNutrition,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ResponsiveMetricList(
                      maxColumns: 2,
                      spacing: 12,
                      children: [
                        NutritionSummaryMetric(
                          label: context.lang.mealFlowNetCarbs,
                          value: '${macros.netCarbsTotal} g',
                          icon: Icons.grass_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        NutritionSummaryMetric(
                          label: context.lang.mealStartEcarbsLabel,
                          value: '${macros.extendedCarbsTotal} g',
                          icon: Icons.history,
                          color: theme.colorScheme.tertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MacronutrientProportions(
                      carbsGrams: macros.carbsTotal,
                      proteinGrams: macros.proteinTotal,
                      fatGrams: macros.fatTotal,
                    ),
                    const SizedBox(height: 12),
                    for (final nutrient in nutrients.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(nutrient.key)),
                            const SizedBox(width: 12),
                            Text(
                              nutrient.value,
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
  }
}
