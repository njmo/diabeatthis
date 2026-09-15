import 'package:flutter/material.dart';

import '../../../../common/widgets/responsive_metric_list.dart';

/// A shared visual surface for live and archived day statistics.
class DayMetricGrid extends StatelessWidget {
  final List<Widget> children;
  const DayMetricGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) => ResponsiveMetricList(
    maxColumns: 2,
    children: [
      for (final child in children)
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
    ],
  );
}
