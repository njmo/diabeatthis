import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/form_section.dart';
import '../../../../common/widgets/nutrition_summary_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../data/models/ingredient_details_data.dart';
import '../utils/reference_ingredient_macro_calculator.dart';
import 'ingredient_energy_summary.dart';

class IngredientNutritionCard extends StatelessWidget {
  const IngredientNutritionCard({super.key, required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final reference = ingredient.isReference;
    final fatPercent =
        (referenceFatShare(
                  fatPer100g: ingredient.fatPer100g,
                  proteinPer100g: ingredient.proteinPer100g,
                ) *
                100)
            .round();
    final colors = Theme.of(context).colorScheme;
    final number = NumberFormat('0.##', lang.localeName);
    Widget metric(String label, double value, IconData icon, Color color) =>
        NutritionSummaryMetric(
          icon: icon,
          color: color,
          label: label,
          value: '${number.format(value)} g',
        );
    return SectionSurface(
      child: FormSection(
        title: reference
            ? lang.ingredientReferenceValues
            : lang.ingredientNutritionValues,
        subtitle: reference ? null : lang.ingredientPer100g,
        children: [
          ResponsiveMetricList(
            maxColumns: 2,
            children: [
              metric(
                reference
                    ? lang.ingredientSimpleCarbsLabel
                    : lang.mealCarbsLabel,
                ingredient.carbsPer100g,
                Icons.grass_outlined,
                colors.primary,
              ),
              if (reference)
                metric(
                  lang.ingredientExtendedCarbsLabel,
                  referenceExtendedCarbsPer100g(
                    fatPer100g: ingredient.fatPer100g,
                    proteinPer100g: ingredient.proteinPer100g,
                  ),
                  Icons.schedule,
                  colors.tertiary,
                )
              else ...[
                metric(
                  lang.mealFatLabel,
                  ingredient.fatPer100g,
                  Icons.opacity,
                  colors.tertiary,
                ),
                metric(
                  lang.mealProteinLabel,
                  ingredient.proteinPer100g,
                  Icons.egg_outlined,
                  colors.secondary,
                ),
                metric(
                  lang.mealFiberLabel,
                  ingredient.fiberPer100g,
                  Icons.eco_outlined,
                  colors.primary,
                ),
              ],
            ],
          ),
          if (reference) ...[
            const SizedBox(height: 16),
            Text(
              lang.ingredientEcarbsSplit(100 - fatPercent, fatPercent),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          IngredientEnergySummary(ingredient: ingredient),
          if (ingredient.barcode?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.barcode_reader,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang.ingredientBarcodeLabel(ingredient.barcode!.trim()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
