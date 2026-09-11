import 'package:flutter/material.dart';

import '../../../../common/widgets/analysis_metric.dart';

/// A bounded visual group for one meal statistic and its supporting context.
class MealStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final int labelLines;
  final IconData? icon;

  const MealStatTile({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.labelLines = 1,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: AnalysisMetric(
      label: label,
      value: value,
      detail: detail,
      labelLines: labelLines,
      icon: icon,
    ),
  );
}
