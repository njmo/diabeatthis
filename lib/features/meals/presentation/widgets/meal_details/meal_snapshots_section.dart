import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealSnapshotsSection extends StatelessWidget {
  final MealDetailsData details;

  const MealSnapshotsSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final rows = _snapshotRows(context, details);

    return MealSectionTile(
      title: context.lang.mealSnapshotsTitle,
      children: [
        for (final row in rows) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 12),
          ResponsiveMetricList(
            children: [
              AnalysisMetric(
                label: context.lang.mealSnapshotsPlanColumn,
                value: formatSnapshotValue(row.plannedValue, row.unit),
              ),
              AnalysisMetric(
                label: context.lang.mealSnapshotsConsumedColumn,
                value: formatSnapshotValue(row.consumedValue, row.unit),
              ),
              AnalysisMetric(
                label: context.lang.mealSnapshotsDifferenceColumn,
                value: formatSnapshotDiff(row.difference, row.unit),
              ),
            ],
          ),
          const Divider(height: 32),
        ],
        const SizedBox(height: 8),
        for (final ingredient in details.ingredients.where((i) => i.isExtra))
          MealInfoRow(
            label: context.lang.mealExtraIngredientLabel,
            value:
                '${ingredient.ingredientName}: ${formatNumber(ingredient.consumedTotalGrams)}g',
          ),
      ],
    );
  }
}

List<MealSnapshotComparisonRowData> _snapshotRows(
  BuildContext context,
  MealDetailsData details,
) {
  final planned = details.plannedSnapshot;
  final consumed = details.consumedSnapshot;
  return [
    MealSnapshotComparisonRowData(
      label: context.lang.mealCarbsLabel,
      plannedValue: planned?.totalCarbsG,
      consumedValue: consumed?.totalCarbsG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: context.lang.mealFatLabel,
      plannedValue: planned?.totalFatG,
      consumedValue: consumed?.totalFatG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: context.lang.mealProteinLabel,
      plannedValue: planned?.totalProteinG,
      consumedValue: consumed?.totalProteinG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: context.lang.mealFiberLabel,
      plannedValue: planned?.totalFiberG,
      consumedValue: consumed?.totalFiberG,
      unit: 'g',
    ),
    MealSnapshotComparisonRowData(
      label: context.lang.mealCaloriesLabel,
      plannedValue: planned?.totalCaloriesKcal,
      consumedValue: consumed?.totalCaloriesKcal,
      unit: 'kcal',
    ),
    MealSnapshotComparisonRowData(
      label: context.lang.mealTotalMassLabel,
      plannedValue: planned?.totalGrams,
      consumedValue: consumed?.totalGrams,
      unit: 'g',
    ),
  ];
}
