import 'package:flutter/material.dart';

import '../../widgets/responsive_metric_list.dart';

/// A shared visual surface for live and archived day statistics.
class DayMetricGrid extends StatelessWidget {
  final List<Widget> children;
  final bool equalRowHeights;
  const DayMetricGrid({
    super.key,
    required this.children,
    this.equalRowHeights = false,
  });

  @override
  Widget build(BuildContext context) => ResponsiveMetricList(
    maxColumns: 2,
    equalRowHeights: equalRowHeights,
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
