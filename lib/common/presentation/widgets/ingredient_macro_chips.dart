import 'package:flutter/material.dart';

import '../../../core/domain/model/ingredient.dart';
import '../../l10n/language.dart';
import 'format_ingredient_metric.dart';
import 'ingredient_metric_chip.dart';

class IngredientMacroChips extends StatelessWidget {
  final Ingredient ingredient;

  const IngredientMacroChips({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        IngredientMetricChip(
          icon: Icons.local_fire_department_outlined,
          label: '${formatIngredientMetric(ingredient.kcalPer100g)} kcal',
        ),
        IngredientMetricChip(
          icon: Icons.grain,
          label: context.lang.ingredientCarbsAmountShort(
            formatIngredientMetric(ingredient.carbsPer100g),
          ),
        ),
        IngredientMetricChip(
          icon: Icons.opacity,
          label: context.lang.ingredientFatAmountShort(
            formatIngredientMetric(ingredient.fatPer100g),
          ),
        ),
        IngredientMetricChip(
          icon: Icons.fitness_center,
          label: context.lang.ingredientProteinAmountShort(
            formatIngredientMetric(ingredient.proteinPer100g),
          ),
        ),
      ],
    );
  }
}
