import 'package:flutter/material.dart';

import '../../../../../common/widgets/detail_metric_tile.dart';
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
    return DetailMetricTile(
      icon: metric.icon,
      label: metric.label,
      value: metric.value,
      unit: metric.unit,
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
