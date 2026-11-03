import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_category.dart';
import '../../models/meal_page_state.dart';
import 'meal_category_edit_button.dart';
import 'meal_detail_formatters.dart';

/// The essential identity and observation state, before any optional detail.
class MealPreviewHeader extends StatelessWidget {
  final MealPageState state;
  final bool showNutrition;

  const MealPreviewHeader({
    super.key,
    required this.state,
    this.showNutrition = true,
  });

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final analysis = state.analysis;
    final messages = context.lang;
    final nutrition = details.preferredNutritionTotals;
    final number = NumberFormat('0.#', messages.localeName);
    final complete = analysis?.hasFullGlucoseWindow == true;
    final status = !details.meal.isEaten
        ? mealStatusLabel(details.meal.status)
        : analysis == null
        ? messages.mealNoAnalysisData
        : !complete
        ? messages.mealPreviewObserving(mealTime(analysis.expectedChartEnd))
        : analysis.postMealGlucoseCoverage.hasSignificantMissing
        ? messages.mealPreviewIncomplete
        : messages.mealPreviewObservationEnded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details.meal.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (MealCategory.fromStorage(details.meal.category) == null)
            MealCategoryEditButton(mealId: details.meal.id, assign: true),
          const SizedBox(height: 6),
          Text(mealDateTime(details.analysisTime)),
          const SizedBox(height: 8),
          Text(status, style: Theme.of(context).textTheme.titleSmall),
          if (state.analysisError != null && details.meal.isEaten) ...[
            const SizedBox(height: 8),
            Text(state.analysisError!),
          ],
          if (showNutrition && nutrition != null && !complete) ...[
            const SizedBox(height: 8),
            Text(
              details.hasConsumedData
                  ? messages.mealPreviewConsumedCarbs(
                      '${number.format(nutrition.totalCarbsG)} g',
                    )
                  : messages.mealPreviewPlannedCarbs(
                      '${number.format(nutrition.totalCarbsG)} g',
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
