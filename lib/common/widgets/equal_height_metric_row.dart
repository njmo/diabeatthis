import 'package:flutter/material.dart';

/// Equalizes a row to its tallest item without fixing its content height.
class EqualHeightMetricRow extends StatelessWidget {
  final List<Widget> children;
  final double itemWidth;
  final double spacing;

  const EqualHeightMetricRow({
    super.key,
    required this.children,
    required this.itemWidth,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(width: spacing),
          SizedBox(width: itemWidth, child: children[index]),
        ],
      ],
    ),
  );
}
