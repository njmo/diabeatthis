import 'package:flutter/material.dart';

/// Content determines height, including when accessibility text is enlarged.
class ResponsiveMetricList extends StatelessWidget {
  final List<Widget> children;
  final int maxColumns;
  final double minimumWidth;

  const ResponsiveMetricList({
    super.key,
    required this.children,
    this.maxColumns = 3,
    this.minimumWidth = 125,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth =
            minimumWidth * MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = ((constraints.maxWidth + 16) / (minWidth + 16))
            .floor()
            .clamp(1, maxColumns);
        final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 20,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
