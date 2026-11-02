import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/language.dart';
import 'meal_completion_decision.dart';

/// Displays a recorded app choice without attributing later actions or outcomes.
class MealCompletionDecisionFact extends StatelessWidget {
  final MealCompletionDecision decision;

  const MealCompletionDecisionFact({super.key, required this.decision});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.#', lang.localeName);
    final difference = decision.consumedCarbs - decision.reportedCarbs;
    final recordedAt = DateFormat(
      'd.MM.yyyy HH:mm',
      lang.localeName,
    ).format(decision.recordedAt.toLocal());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.fact_check_outlined),
      title: Text(switch (decision.choice) {
        MealCarbsCorrectionChoice.withoutCorrection =>
          lang.mealCompletionDecisionWithoutCorrection,
        MealCarbsCorrectionChoice.correctionRequested =>
          lang.mealCompletionDecisionCorrectionRequested,
      }),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.mealCompletionDecisionRecordedAt(recordedAt)),
          Text(
            lang.mealCompletionDecisionCarbs(
              number.format(decision.reportedCarbs),
              number.format(decision.consumedCarbs),
              '${difference > 0 ? '+' : ''}${number.format(difference)}',
            ),
          ),
          Text(lang.mealCompletionDecisionContext),
        ],
      ),
    );
  }
}
