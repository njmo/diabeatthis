import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/manual_meal_decision.dart';
import '../../../../../common/meal/stored_meal_decision.dart';
import '../../../../../common/widgets/information_button.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../data/models/meal_details_data.dart';
import '../../controllers/meal_application_review_controller.dart';
import 'meal_detail_formatters.dart';

class MealAdviceExplanation extends StatelessWidget {
  const MealAdviceExplanation({super.key, required this.details});
  final MealDetailsData details;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final decision = details.advisorDecision;
    final reason = switch (decision?.decisionReason) {
      'lowBeforeMealEffect' => lang.mealReasonLowBeforeEffect,
      'nearLowWithLowBgOrIob' => lang.mealReasonNearLowIob,
      'nearLowImmediateMeal' => lang.mealReasonNearLowImmediate,
      'highBgNotFalling' => lang.mealReasonHighNotFalling,
      'immediateMeal' => lang.mealReasonImmediate,
      _ => lang.mealReasonMissing,
    };
    return SummaryDetailCard(
      title: lang.mealReasonTitle,
      icon: Icons.psychology_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (decision == null)
            Text(lang.mealNoRecord)
          else ...[
            Text(
              '${storedMealDecisionLabel(decision.result)} · ${mealTime(decision.createdAt)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (decision.isManual)
              Text(
                mealDecisionLabel(
                  const MealApplicationReviewController().manualChoice(details),
                ),
              ),
            if (!decision.isManual) ...[
              const SizedBox(height: 8),
              Text(reason),
              if (decision.initialWaitTime > 0)
                Text(
                  '${lang.mealWaitProposed}: ${decision.initialWaitTime} min',
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InformationButton(
                  title: lang.mealReasonTitle,
                  message: lang.mealReasonCalculationMissing,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
