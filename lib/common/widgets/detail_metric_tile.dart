import 'package:flutter/material.dart';

import 'information_button.dart';

/// A reusable statistic tile shared by detail pages.
class DetailMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? detail;
  final double borderRadius;
  final String? explanation;
  final int minimumLabelLines;

  const DetailMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.detail,
    this.borderRadius = 8,
    this.explanation,
    this.minimumLabelLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium;
    final labelHeight =
        (MediaQuery.textScalerOf(context).scale(labelStyle?.fontSize ?? 12) *
                (labelStyle?.height ?? 1.33) *
                minimumLabelLines)
            .ceilToDouble();

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: colors.outlineVariant),
            color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: minimumLabelLines <= 1 ? 0 : labelHeight,
                      ),
                      child: Text(label, style: labelStyle),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        text: value,
                        children: [
                          if (unit != null)
                            TextSpan(
                              text: ' $unit',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(detail!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        if (explanation != null)
          Positioned(
            top: -12,
            right: -8,
            child: Material(
              color: colors.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: InformationButton(title: label, message: explanation!),
            ),
          ),
      ],
    );
  }
}
