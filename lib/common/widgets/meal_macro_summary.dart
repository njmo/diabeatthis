import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/language.dart';
import '../nutrition/macro_colors.dart';
import 'carbohydrate_totals_summary.dart';
import 'equal_height_tile_grid.dart';
import 'macro_distribution_bar.dart';
import 'macro_value_tile.dart';

/// Whole-portion macros. Carbs are net, so fiber has its own gram share.
class MealMacroSummary extends StatelessWidget {
  const MealMacroSummary({
    super.key,
    required this.netCarbs,
    required this.protein,
    required this.fat,
    required this.fiber,
    required this.calories,
    this.weightGrams,
    this.showEnergy = true,
  });

  final double netCarbs;
  final double protein;
  final double fat;
  final double fiber;
  final double calories;
  final double? weightGrams;
  final bool showEnergy;

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('0.0', context.lang.localeName);
    final metrics = [
      (context.lang.mealNetCarbsLabel, netCarbs, MacroColors.carbs),
      (context.lang.mealProteinLabel, protein, MacroColors.protein),
      (context.lang.mealFatLabel, fat, MacroColors.fat),
      (context.lang.mealFiberLabel, fiber, MacroColors.fiber),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
            final columns = constraints.maxWidth < 260 || largeText ? 2 : 4;
            return EqualHeightTileGrid(
              columns: columns,
              children: [
                for (final (label, value, color) in metrics)
                  MacroValueTile(
                    label: label,
                    value: '${number.format(value)} g',
                    accentColor: color,
                    compact: columns == 4,
                  ),
              ],
            );
          },
        ),
        MacroDistributionBar(
          carbs: netCarbs,
          protein: protein,
          fat: fat,
          fiber: fiber,
          basisLabel: '',
          compact: true,
          showLegend: false,
        ),
        const SizedBox(height: 4),
        CarbohydrateTotalsSummary(
          netCarbs: netCarbs,
          protein: protein,
          fat: fat,
        ),
        if (showEnergy) const SizedBox(height: 12),
        if (showEnergy)
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${calories.round()} kcal',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (weightGrams != null) Text('· ${weightGrams!.round()} g'),
            ],
          ),
      ],
    );
  }
}
