import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'meal_comparison_bar.dart';

/// A shared scale for recorded values in one unit; unknown stays unknown.
class RecordValueBars extends StatelessWidget {
  const RecordValueBars({super.key, required this.values});
  final List<({String label, double? value, String formatted, Color color})>
  values;

  @override
  Widget build(BuildContext context) {
    final maximum = values.fold<double>(
      1,
      (maximum, item) => item.value?.isFinite == true
          ? math.max(maximum, item.value!)
          : maximum,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in values)
          MealComparisonBar(
            label: item.label,
            valueLabel: item.formatted,
            value: item.value,
            maximum: maximum,
            color: item.color,
          ),
      ],
    );
  }
}
