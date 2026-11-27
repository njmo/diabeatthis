import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../data/domain/use_cases/load_meal_progress_history_use_case.dart';
import '../../controllers/meal_application_review_controller.dart';
import '../../models/meal_page_state.dart';
import '../../models/meal_progress_now.dart';
import 'meal_advice_explanation.dart';
import 'meal_application_differences.dart';
import 'meal_completion_choice_card.dart';
import 'meal_progress_calculator_card.dart';
import 'meal_progress_now_card.dart';
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
    final inProgress = LoadMealProgressHistoryUseCase.appliesTo(details);
    final progress = inProgress
        ? MealProgressNow.from(
            details: details,
            history: state.progressHistory,
            proposal: const MealApplicationReviewController().proposedEcarbs(
              details,
            ),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null) ...[
          MealProgressNowCard(progress: progress),
          const SizedBox(height: 16),
        ],
        MealCompletionChoiceCard(decision: details.meal.completionDecision),
        // Proposal and outcome can only be compared once the meal is eaten.
        if (details.meal.isEaten) ...[
          MealApplicationDifferences(state: state),
          const SizedBox(height: 16),
        ],
        MealAdviceExplanation(details: details),
        const SizedBox(height: 16),
        MealRecordedActions(details: details),
        const SizedBox(height: 16),
        if (analysis != null && details.meal.isEaten)
          MealRecordedCarbsCard(details: details, analysis: analysis)
        else if (progress != null)
          MealProgressCalculatorCard(
            details: details,
            history: state.progressHistory,
          )
        else
          SummaryDetailCard(
            title: context.lang.mealRecordedCarbsTitle,
            icon: Icons.calculate_outlined,
            child: Text(context.lang.uiHistoryIsNotAvailableYet),
          ),
        const SizedBox(height: 16),
        MealProposedEcarbsCard(
          details: details,
          progress: progress?.extendedCarbs,
        ),
        const SizedBox(height: 16),
        MealSavedInformationCard(state: state),
      ],
    );
  }
}
