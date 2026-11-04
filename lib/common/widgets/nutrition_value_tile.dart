import 'package:flutter/material.dart';

/// A compact macro amount with an accessible, wrapping label.
class NutritionValueTile extends StatelessWidget {
  const NutritionValueTile({
    super.key,
    required this.label,
    required this.value,
    this.accentColor,
    this.compact = false,
  });
  final String label;
  final String value;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      border: accentColor == null
          ? null
          : Border.all(color: accentColor!, width: 1.5),
    ),
    child: Padding(
      padding: EdgeInsets.all(compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: Theme.of(context).textTheme.titleSmall),
            )
          else
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            label,
            style: compact
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
