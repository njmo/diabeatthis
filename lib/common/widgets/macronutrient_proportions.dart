import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/language.dart';

/// Relative mass of the three macronutrients, excluding fiber and eCarbs.
class MacronutrientProportions extends StatelessWidget {
  const MacronutrientProportions({
    super.key,
    required this.carbsGrams,
    required this.proteinGrams,
    required this.fatGrams,
  });

  final int carbsGrams;
  final int proteinGrams;
  final int fatGrams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nutrients = [
      (
        label: context.lang.mealFlowTotalCarbs,
        grams: math.max(0, carbsGrams),
        color: Colors.blue,
      ),
      (
        label: context.lang.mealProteinLabel,
        grams: math.max(0, proteinGrams),
        color: Colors.green,
      ),
      (
        label: context.lang.mealFatLabel,
        grams: math.max(0, fatGrams),
        color: Colors.orange,
      ),
    ];
    final total = nutrients.fold(0, (sum, nutrient) => sum + nutrient.grams);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.mealMacroProportionsByWeight,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? ColoredBox(color: theme.colorScheme.surfaceContainerHighest)
                  : Row(
                      children: [
                        for (final nutrient in nutrients)
                          if (nutrient.grams > 0)
                            Expanded(
                              flex: nutrient.grams,
                              child: ColoredBox(
                                color: nutrient.color,
                                child: const SizedBox.expand(),
                              ),
                            ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final nutrient in nutrients)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: nutrient.color,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 8),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${nutrient.label}: ${nutrient.grams} g · ${total == 0 ? 0 : (100 * nutrient.grams / total).round()}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
