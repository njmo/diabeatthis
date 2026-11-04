import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../meal/meal_extended_carbs.dart';
import '../nutrition/macro_colors.dart';
import '../nutrition/stable_macro_ceil.dart';
import 'equal_height_tile_grid.dart';
import 'nutrition_value_tile.dart';
import 'proportion_bar.dart';

/// Uses the same rounding and extended-carb conversion as the meal start flow.
class CarbohydrateTotalsSummary extends StatelessWidget {
  const CarbohydrateTotalsSummary({
    super.key,
    required this.netCarbs,
    required this.protein,
    required this.fat,
  });
  final double netCarbs;
  final double protein;
  final double fat;

  @override
  Widget build(BuildContext context) {
    final extended = mealExtendedCarbsFromNutrients(
      fatGrams: fat,
      proteinGrams: protein,
    );
    final carbs = netCarbs.ceilMacro();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EqualHeightTileGrid(
          columns: 2,
          children: [
            NutritionValueTile(
              label: context.lang.mealMacroCarbsTotal,
              value: context.lang.mealStartGrams(carbs),
              accentColor: MacroColors.carbs,
            ),
            NutritionValueTile(
              label: context.lang.mealStartEcarbsLabel,
              value: context.lang.mealStartGrams(extended),
              accentColor: MacroColors.fat,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProportionBar(
          values: [carbs.toDouble(), extended.toDouble()],
          colors: const [MacroColors.carbs, MacroColors.fat],
          labels: [
            context.lang.mealMacroCarbsTotal,
            context.lang.mealStartEcarbsLabel,
          ],
          height: 20,
          showPercentages: true,
        ),
      ],
    );
  }
}
