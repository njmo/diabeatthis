import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../models/meal_page_state.dart';
import 'meal_advice_explanation.dart';
import 'meal_application_differences.dart';
import 'meal_completion_choice_card.dart';
import 'meal_proposed_ecarbs_card.dart';
import 'meal_recorded_actions.dart';
import 'meal_recorded_carbs_card.dart';
import 'meal_saved_information_card.dart';

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
        MealCompletionChoiceCard(decision: details.meal.completionDecision),
        MealApplicationDifferences(state: state),
        const SizedBox(height: 16),
        MealAdviceExplanation(details: details),
        const SizedBox(height: 16),
        MealRecordedActions(details: details),
        if (analysis != null && details.meal.isEaten) ...[
          const SizedBox(height: 16),
          MealRecordedCarbsCard(details: details, analysis: analysis),
        ] else ...[
          const SizedBox(height: 16),
          SummaryDetailCard(
            title: context.lang.mealRecordedCarbsTitle,
            icon: Icons.calculate_outlined,
            child: Text(context.lang.uiHistoryIsNotAvailableYet),
          ),
        ],
        const SizedBox(height: 16),
        MealProposedEcarbsCard(details: details),
        const SizedBox(height: 16),
        MealSavedInformationCard(state: state),
      ],
    );
  }
}
