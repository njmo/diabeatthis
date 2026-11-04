import 'package:flutter/material.dart';

import 'equal_height_metric_row.dart';

/// Content determines height, including when accessibility text is enlarged.
class ResponsiveMetricList extends StatelessWidget {
  final List<Widget> children;
  final int maxColumns;
  final double minimumWidth;
  final double spacing;
  final double runSpacing;
  final bool equalRowHeights;

  const ResponsiveMetricList({
    super.key,
    required this.children,
    this.maxColumns = 3,
    this.minimumWidth = 125,
    this.spacing = 16,
    this.runSpacing = 20,
    this.equalRowHeights = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth =
            minimumWidth * MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns =
            ((constraints.maxWidth + spacing) / (minWidth + spacing))
                .floor()
                .clamp(1, maxColumns);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        if (equalRowHeights) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (
                var start = 0;
                start < children.length;
                start += columns
              ) ...[
                if (start > 0) SizedBox(height: runSpacing),
                EqualHeightMetricRow(
                  itemWidth: width,
                  spacing: spacing,
                  children: children.sublist(
                    start,
                    (start + columns).clamp(0, children.length),
                  ),
                ),
              ],
            ],
          );
        }
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
