import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/value_comparison_bars.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_detail_formatters.dart';

class MealSnapshotComparisonRow extends StatelessWidget {
  final MealSnapshotComparisonRowData row;
  final String? plannedLabel;
  final String? consumedLabel;

  const MealSnapshotComparisonRow({
    super.key,
    required this.row,
    this.plannedLabel,
    this.consumedLabel,
  });

  @override
  Widget build(BuildContext context) => ValueComparisonBars(
    label: row.label,
    firstLabel: plannedLabel ?? context.lang.mealSnapshotsPlanColumn,
    firstValueLabel: formatSnapshotValue(row.plannedValue, row.unit),
    firstValue: row.plannedValue,
    secondLabel: consumedLabel ?? context.lang.mealSnapshotsConsumedColumn,
    secondValueLabel: formatSnapshotValue(row.consumedValue, row.unit),
    secondValue: row.consumedValue,
    differenceLabel:
        '${context.lang.mealSnapshotsDifferenceColumn}: ${formatSnapshotDiff(row.difference, row.unit)}',
  );
}
