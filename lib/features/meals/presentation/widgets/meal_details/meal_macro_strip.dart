import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_formatters.dart';

class MealMacroStrip extends StatelessWidget {
  final MealSnapshotDetailsData snapshot;

  const MealMacroStrip({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = {
      context.lang.mealCarbsLabel: snapshot.totalCarbsG,
      context.lang.mealProteinLabel: snapshot.totalProteinG,
      context.lang.mealFatLabel: snapshot.totalFatG,
    };
    return ResponsiveMetricList(
      minimumWidth: 80,
      children: [
        for (final entry in values.entries)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatGrams(entry.value),
                style: theme.textTheme.titleMedium,
              ),
              Text(
                entry.key,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
