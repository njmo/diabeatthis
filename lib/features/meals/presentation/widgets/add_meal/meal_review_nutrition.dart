import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/meal_macro_summary.dart';
import '../../../../../common/widgets/section_surface.dart';
import '../../../data/providers/meal_draft_nutrition_totals_provider.dart';

class MealReviewNutrition extends ConsumerWidget {
  const MealReviewNutrition({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(mealDraftNutritionTotalsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text(context.lang.mealIngredientsLoadError(error)),
        data: (nutrition) => SectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.lang.mealFlowNutrition,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              MealMacroSummary(
                netCarbs: nutrition.totalNetCarbsG,
                protein: nutrition.totalProteinG,
                fat: nutrition.totalFatG,
                fiber: nutrition.totalFiberG,
                calories: nutrition.totalCaloriesKcal,
                weightGrams: nutrition.totalGrams,
              ),
            ],
          ),
        ),
      );
}
