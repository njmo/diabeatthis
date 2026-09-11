import 'package:flutter/material.dart';

class MealComparisonBar extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double? value;
  final double maximum;
  final Color color;
  const MealComparisonBar({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.maximum,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(valueLabel, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 4),
        if (value != null && value!.isFinite && value! >= 0)
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maximum > 0 ? (value! / maximum).clamp(0, 1) : 0,
                minHeight: 8,
                color: color,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
      ],
    ),
  );
}
