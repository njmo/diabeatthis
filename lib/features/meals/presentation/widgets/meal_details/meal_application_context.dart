import 'package:flutter/material.dart';

import '../../../data/models/meal_start_context_data.dart';
import '../../models/meal_page_state.dart';
import 'meal_advice_explanation.dart';
import 'meal_advice_history_section.dart';
import 'meal_advisor_result_section.dart';
import 'meal_category_edit_button.dart';
import 'meal_comparison_section.dart';
import 'meal_recorded_actions.dart';
import 'meal_recorded_carbs_card.dart';
import 'meal_technical_section.dart';
import 'meal_wait_comparison.dart';

class MealApplicationContext extends StatelessWidget {
  const MealApplicationContext({super.key, required this.state});
  final MealPageState state;

  @override
  Widget build(BuildContext context) {
    final details = state.details;
    final analysis = state.analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MealAdviceExplanation(details: details),
        if (analysis != null)
          MealWaitComparison(
            data: MealStartContextData(details: details, analysis: analysis),
            visual: true,
          ),
        const SizedBox(height: 16),
        MealRecordedActions(details: details),
        if (analysis != null && details.meal.isEaten) ...[
          const SizedBox(height: 16),
          MealRecordedCarbsCard(details: details, analysis: analysis),
        ],
        const SizedBox(height: 16),
        MealAdviceHistorySection(details: details, analysis: analysis),
        const SizedBox(height: 16),
        MealAdvisorResultSection(details: details),
        if (analysis != null && details.meal.isEaten)
          MealComparisonSection(details: details, analysis: analysis),
        MealCategoryEditButton(mealId: details.meal.id),
        MealTechnicalSection(state: state),
      ],
    );
  }
}
