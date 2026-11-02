import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'meal_comparison_bar.dart';

class ValueComparisonBars extends StatelessWidget {
  const ValueComparisonBars({
    super.key,
    required this.label,
    required this.firstLabel,
    required this.firstValueLabel,
    required this.firstValue,
    required this.secondLabel,
    required this.secondValueLabel,
    required this.secondValue,
    this.differenceLabel,
  });

  final String label;
  final String firstLabel;
  final String firstValueLabel;
  final double? firstValue;
  final String secondLabel;
  final String secondValueLabel;
  final double? secondValue;
  final String? differenceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maximum = math.max(firstValue ?? 0, secondValue ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          MealComparisonBar(
            label: firstLabel,
            valueLabel: firstValueLabel,
            value: firstValue,
            maximum: maximum,
            color: theme.colorScheme.outline,
          ),
          MealComparisonBar(
            label: secondLabel,
            valueLabel: secondValueLabel,
            value: secondValue,
            maximum: maximum,
            color: theme.colorScheme.primary,
          ),
          if (differenceLabel != null) ...[
            const SizedBox(height: 8),
            Text(differenceLabel!, style: theme.textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}
