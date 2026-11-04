import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../nutrition/macro_colors.dart';
import 'proportion_bar.dart';

/// Segment widths represent macro grams, not energy percentages.
class MacroDistributionBar extends StatelessWidget {
  const MacroDistributionBar({
    super.key,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.fiber,
    required this.basisLabel,
    this.compact = false,
    this.showLegend = true,
  });
  final double carbs;
  final double protein;
  final double fat;
  final double? fiber;
  final String basisLabel;
  final bool compact;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final values = [carbs, protein, fat, if (fiber != null) fiber!];
    final labels = [
      compact ? context.lang.ingredientCarbsShort : context.lang.mealCarbsLabel,
      compact
          ? context.lang.ingredientProteinShort
          : context.lang.mealProteinLabel,
      compact ? context.lang.ingredientFatShort : context.lang.mealFatLabel,
      if (fiber != null) context.lang.mealFiberLabel,
    ];
    final colors = [
      MacroColors.carbs,
      MacroColors.protein,
      MacroColors.fat,
      if (fiber != null) MacroColors.fiber,
    ];
    final total = values.fold(0.0, (sum, value) => sum + value);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (basisLabel.isNotEmpty) ...[
            Text(basisLabel, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
          ],
          ProportionBar(values: values, colors: colors, labels: labels),
          if (showLegend) const SizedBox(height: 8),
          if (showLegend)
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (var i = 0; i < values.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: colors[i]),
                      const SizedBox(width: 4),
                      Text(
                        '${labels[i]} ${values[i].toStringAsFixed(1)} g · ${total > 0 ? (values[i] / total * 100).round() : 0}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
