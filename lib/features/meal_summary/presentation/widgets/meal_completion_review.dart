import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_extended_carbs.dart';
import '../../../meals/data/models/meal_analysis_data.dart';
import '../../../meals/presentation/widgets/meal_details/meal_snapshot_comparison_row.dart';
import '../models/meal_summary_draft.dart';
import '../utils/meal_summary_nutrition_comparison.dart';

class MealCompletionReview extends StatelessWidget {
  const MealCompletionReview({super.key, required this.draft});

  final MealSummaryDraft draft;

  @override
  Widget build(BuildContext context) {
    final totals = calculateMealSummaryNutritionComparison(draft);
    final planned = totals.planned;
    final consumed = totals.consumed;
    final rows = [
      if (totals.hasKnownMass)
        (
          label: context.lang.mealTotalMassLabel,
          planned: planned.totalGrams,
          consumed: consumed.totalGrams,
        ),
      (
        label: context.lang.similarMealNetCarbs,
        planned: planned.netCarbsGrams,
        consumed: consumed.netCarbsGrams,
      ),
      (
        label: context.lang.mealProteinLabel,
        planned: planned.proteinGrams,
        consumed: consumed.proteinGrams,
      ),
      (
        label: context.lang.mealFatLabel,
        planned: planned.fatGrams,
        consumed: consumed.fatGrams,
      ),
      (
        label: context.lang.mealStartEcarbsLabel,
        planned: planned.fatGrams.isFinite && planned.proteinGrams.isFinite
            ? mealExtendedCarbsFromMacros(planned).toDouble()
            : double.nan,
        consumed: consumed.fatGrams.isFinite && consumed.proteinGrams.isFinite
            ? mealExtendedCarbsFromMacros(consumed).toDouble()
            : double.nan,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text(
          context.lang.mealSnapshotsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final row in rows)
          MealSnapshotComparisonRow(
            row: MealSnapshotComparisonRowData(
              label: row.label,
              plannedValue: row.planned.isFinite ? row.planned : null,
              consumedValue: row.consumed.isFinite ? row.consumed : null,
              unit: 'g',
            ),
            plannedLabel: context.lang.mealCompletionPlanned,
          ),
      ],
    );
  }
}
