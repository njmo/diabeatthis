import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../domain/models/meal_application_review.dart';
import '../../controllers/meal_application_review_controller.dart';
import '../../models/meal_page_state.dart';
import 'meal_difference_summary.dart';

class MealApplicationDifferences extends StatelessWidget {
  const MealApplicationDifferences({super.key, required this.state});
  final MealPageState state;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final data = const MealApplicationReviewController().build(state);
    final proposed = data.proposedWait;
    final actual = data.actualWait;
    final number = NumberFormat('0.#', lang.localeName);
    final consumed = data.consumedCarbs;
    final calculator = data.calculatorCarbs;
    final sameCarbs = data.carbsMatch == true;
    return SummaryDetailCard(
      title: lang.mealDifferencesTitle,
      icon: Icons.compare_arrows_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (proposed != null)
            MealDifferenceSummary(
              title: lang.mealDifferenceWait,
              value: actual == null
                  ? lang.mealDifferenceUnavailable
                  : '${formatDurationLabel(proposed)} → ${formatDurationLabel(actual)}\n${data.waitComparison == MealWaitComparison.matched
                        ? lang.mealWaitMatched
                        : data.waitComparison == MealWaitComparison.shorter
                        ? lang.mealWaitShorter(formatDurationLabel(data.waitDifference!))
                        : lang.mealWaitLonger(formatDurationLabel(data.waitDifference!))}',
              icon: Icons.timer_outlined,
              different: actual != null && proposed != actual,
            ),
          MealDifferenceSummary(
            title: lang.mealDifferenceCarbs,
            value: data.calculatorCount > 1
                ? lang.mealDifferenceMultiple
                : consumed == null || calculator == null
                ? lang.mealDifferenceUnavailable
                : sameCarbs
                ? '${number.format(consumed)} g · ${lang.mealDifferenceMatched}'
                : '${number.format(consumed)} g → ${number.format(calculator)} g',
            icon: Icons.calculate_outlined,
            different: consumed != null && calculator != null && !sameCarbs,
          ),
        ],
      ),
    );
  }
}
