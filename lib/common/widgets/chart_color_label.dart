import 'package:flutter/material.dart';

class ChartColorLabel extends StatelessWidget {
  final Color color;
  final String label;
  const ChartColorLabel({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Icon(Icons.square_rounded, color: color, size: 10),
      ),
      const SizedBox(width: 4),
      Flexible(child: Text(label)),
    ],
  );
}
