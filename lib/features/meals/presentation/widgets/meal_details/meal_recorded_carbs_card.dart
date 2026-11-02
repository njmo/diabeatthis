import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/record_value_bars.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../data/models/meal_advice_history_comparison.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_formatters.dart';

class MealRecordedCarbsCard extends StatelessWidget {
  const MealRecordedCarbsCard({
    super.key,
    required this.details,
    required this.analysis,
  });
  final MealDetailsData details;
  final MealAnalysisData analysis;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    String grams(double? amount) =>
        amount == null ? '—' : '${number.format(amount)} g';
    final wizards = MealAdviceHistoryComparison(analysis).wizards;
    return SummaryDetailCard(
      title: lang.mealRecordedCarbsTitle,
      icon: Icons.calculate_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecordValueBars(
            values: [
              (
                label: '${lang.mealReviewPlanned} · ${lang.beforeMealCarbs}',
                value: details.plannedNutritionTotals?.totalNetCarbsG,
                formatted: grams(
                  details.plannedNutritionTotals?.totalNetCarbsG,
                ),
                color: Theme.of(context).colorScheme.secondary,
              ),
              (
                label: '${lang.mealReviewConsumed} · ${lang.beforeMealCarbs}',
                value: details.consumedSnapshot?.totalNetCarbsG,
                formatted: grams(details.consumedSnapshot?.totalNetCarbsG),
                color: Theme.of(context).colorScheme.primary,
              ),
              for (final wizard in wizards)
                (
                  label:
                      '${lang.historyBolusWizard} · ${mealTime(wizard.createdAt)}',
                  value: wizard.calculatorResult?.carbs,
                  formatted: grams(wizard.calculatorResult?.carbs),
                  color: Theme.of(context).colorScheme.tertiary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${mealDateTime(analysis.eventStart)} – ${mealDateTime(analysis.eventEnd)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (wizards.isEmpty) Text(lang.uiNoBolusWizardEntryInTheLoadedWindow),
          for (final wizard in wizards) ...[
            const Divider(),
            Text(
              '${lang.historyBolusWizard} · ${mealTime(wizard.createdAt)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (wizard.calculatorResult?.totalInsulin != null)
              Text(
                lang.mealRecordedCalculatedInsulin(
                  number.format(wizard.calculatorResult!.totalInsulin!),
                ),
              ),
            if (wizard.carbohydrateRecord?.isValid == true)
              Text(
                lang.mealRecordedCarbEntry(
                  grams(wizard.carbohydrateRecord!.carbs.toDouble()),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Text(
            lang.mealRecordedCarbsCaution,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
