import 'package:flutter/material.dart';

import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../models/meal_metric_view_data.dart';

class MealMetricGrid extends StatelessWidget {
  final List<MealMetricTileData> metrics;
  final int compactColumns;
  final int wideColumns;

  const MealMetricGrid({
    super.key,
    required this.metrics,
    this.compactColumns = 2,
    this.wideColumns = 4,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveMetricList(
      maxColumns: wideColumns,
      children: [for (final metric in metrics) MealMetricTile(metric: metric)],
    );
  }
}

class MealMetricTile extends StatelessWidget {
  final MealMetricTileData metric;

  const MealMetricTile({super.key, required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(metric.icon, size: 20, color: colors.primary),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: metric.value,
                    children: [
                      if (metric.unit != null)
                        TextSpan(
                          text: ' ${metric.unit}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MealCompactMetricBar extends StatelessWidget {
  final List<MealCompactMetricData> metrics;

  const MealCompactMetricBar({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: ResponsiveMetricList(
          maxColumns: 4,
          children: [
            for (final metric in metrics) MealCompactMetric(metric: metric),
          ],
        ),
      ),
    );
  }
}

class MealCompactMetric extends StatelessWidget {
  final MealCompactMetricData metric;

  const MealCompactMetric({super.key, required this.metric});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(metric.label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(
          metric.value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}
