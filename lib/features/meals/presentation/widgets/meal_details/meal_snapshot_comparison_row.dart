import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../common/widgets/meal_comparison_bar.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_detail_formatters.dart';

class MealSnapshotComparisonRow extends StatelessWidget {
  final MealSnapshotComparisonRowData row;
  const MealSnapshotComparisonRow({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final theme = Theme.of(context);
    final maximum = math
        .max(row.plannedValue ?? 0, row.consumedValue ?? 0)
        .toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.label, style: theme.textTheme.titleSmall),
          MealComparisonBar(
            label: lang.mealSnapshotsPlanColumn,
            valueLabel: formatSnapshotValue(row.plannedValue, row.unit),
            value: row.plannedValue,
            maximum: maximum,
            color: theme.colorScheme.outline,
          ),
          MealComparisonBar(
            label: lang.mealSnapshotsConsumedColumn,
            valueLabel: formatSnapshotValue(row.consumedValue, row.unit),
            value: row.consumedValue,
            maximum: maximum,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            '${lang.mealSnapshotsDifferenceColumn}: ${formatSnapshotDiff(row.difference, row.unit)}',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
