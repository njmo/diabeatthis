import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_completion_decision.dart';
import '../../../../../common/widgets/record_value_bars.dart';
import '../../../../../common/widgets/summary_detail_card.dart';

class MealCompletionChoiceCard extends StatelessWidget {
  const MealCompletionChoiceCard({super.key, required this.decision});
  final MealCompletionDecision? decision;
  @override
  Widget build(BuildContext context) {
    final data = decision;
    if (data == null) {
      return const SizedBox.shrink();
    }
    final lang = context.lang;
    final colors = Theme.of(context).colorScheme;
    final number = NumberFormat('0.#', lang.localeName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SummaryDetailCard(
        title: lang.mealCompletionChoiceTitle,
        icon: Icons.fact_check_outlined,
        explanation: lang.mealCompletionChoiceNote,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecordValueBars(
              values: [
                (
                  label: lang.mealPreviouslyReported,
                  value: data.reportedCarbs,
                  formatted: '${number.format(data.reportedCarbs)} g',
                  color: colors.secondary,
                ),
                (
                  label: lang.mealReviewConsumed,
                  value: data.consumedCarbs,
                  formatted: '${number.format(data.consumedCarbs)} g',
                  color: colors.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data.choice == MealCarbsCorrectionChoice.correctionRequested
                  ? lang.mealCorrectionChosen
                  : lang.mealCorrectionNotChosen,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${number.format(data.proposedCorrectionCarbs)} g · ${DateFormat('HH:mm', lang.localeName).format(data.recordedAt.toLocal())}',
            ),
          ],
        ),
      ),
    );
  }
}
