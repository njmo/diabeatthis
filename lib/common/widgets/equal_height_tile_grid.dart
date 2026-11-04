import 'package:flutter/material.dart';

/// Equal widths and content-driven matching heights within each tile row.
class EqualHeightTileGrid extends StatelessWidget {
  const EqualHeightTileGrid({
    super.key,
    required this.children,
    required this.columns,
    this.spacing = 8,
  }) : assert(columns > 0);

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var start = 0; start < children.length; start += columns) ...[
        if (start > 0) SizedBox(height: spacing),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) SizedBox(width: spacing),
                Expanded(
                  child: start + column < children.length
                      ? children[start + column]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}
