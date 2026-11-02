import 'package:flutter/material.dart';

/// A short row of equally sized choices whose height follows their content.
class HorizontalChoiceList extends StatelessWidget {
  const HorizontalChoiceList({
    super.key,
    required this.children,
    required this.itemWidth,
    this.spacing = 10,
  });

  final List<Widget> children;
  final double itemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) SizedBox(width: spacing),
              SizedBox(width: itemWidth, child: children[index]),
            ],
          ],
        ),
      ),
    );
  }
}
