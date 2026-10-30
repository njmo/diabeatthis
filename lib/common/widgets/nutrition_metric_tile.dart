import 'package:flutter/material.dart';

class NutritionMetricTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final Color? iconColor;
  final String label;
  final String value;
  final bool emphasized;
  final double iconSize;
  final double iconSpacing;

  const NutritionMetricTile({
    this.icon,
    this.leading,
    this.iconColor,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.iconSize = 24,
    this.iconSpacing = 10,
    super.key,
  }) : assert(icon != null || leading != null);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconTheme.merge(
              data: IconThemeData(
                size: iconSize,
                color:
                    iconColor ??
                    (emphasized
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant),
              ),
              child: leading ?? Icon(icon),
            ),
            SizedBox(width: iconSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: emphasized
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: textTheme.titleMedium?.copyWith(
                      color: emphasized ? colorScheme.onPrimaryContainer : null,
                      fontWeight: emphasized ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
