import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/record_value_bars.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../data/models/meal_details_data.dart';
import '../../../data/models/meal_progress_history.dart';
import '../../controllers/meal_application_review_controller.dart';
import 'meal_detail_formatters.dart';

/// Planned carbohydrates and calculator entries of a meal still in progress.
/// The eaten portion is compared only after the meal.
class MealProgressCalculatorCard extends StatelessWidget {
  const MealProgressCalculatorCard({
    super.key,
    required this.details,
    required this.history,
  });

  final MealDetailsData details;
  final MealProgressHistory? history;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    String grams(double? amount) =>
        amount == null ? '—' : '${number.format(amount)} g';
    const controller = MealApplicationReviewController();
    final wizards = history?.calculators ?? const <BolusWizard>[];
    String wizardLabel(BolusWizard wizard) =>
        '${controller.isAssignedCalculator(details, wizard) ? lang.mealLinkedCalculator : lang.mealWindowCalculator} · ${mealTime(wizard.createdAt)}';
    final planned = details.plannedNutritionTotals?.totalNetCarbsG;
    return SummaryDetailCard(
      title: lang.mealRecordedCarbsTitle,
      icon: Icons.calculate_outlined,
      explanation: lang.mealRecordedCarbsCaution,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecordValueBars(
            values: [
              (
                label: '${lang.mealReviewPlanned} · ${lang.beforeMealCarbs}',
                value: planned,
                formatted: grams(planned),
                color: Theme.of(context).colorScheme.secondary,
              ),
              for (final wizard in wizards)
                (
                  label: wizardLabel(wizard),
                  value: wizard.calculatorResult?.carbs,
                  formatted: grams(wizard.calculatorResult?.carbs),
                  color: Theme.of(context).colorScheme.tertiary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (wizards.isEmpty) Text(lang.mealRecordedCarbsNoCalculatorYet),
          for (final wizard in wizards)
            if (wizard.calculatorResult?.totalInsulin != null)
              Text(
                '${wizardLabel(wizard)}: ${lang.mealRecordedCalculatedInsulin(number.format(wizard.calculatorResult!.totalInsulin!))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          const SizedBox(height: 8),
          Text(
            lang.mealRecordedCarbsConsumedLater,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
