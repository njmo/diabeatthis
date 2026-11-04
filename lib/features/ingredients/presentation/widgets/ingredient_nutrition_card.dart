import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/form_section.dart';
import '../../../../common/widgets/label_value_row.dart';
import '../../../../common/widgets/meal_macro_summary.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';
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
    return SectionSurface(
      child: FormSection(
        title: reference
            ? lang.ingredientReferenceValues
            : lang.ingredientNutritionValues,
        subtitle: reference ? null : lang.ingredientPer100g,
        children: [
          MealMacroSummary(
            netCarbs: calculateNetCarbs(
              carbs: ingredient.carbsPer100g,
              fiber: ingredient.fiberPer100g,
              labelMode: ingredient.carbsLabelMode,
            ),
            protein: ingredient.proteinPer100g,
            fat: ingredient.fatPer100g,
            fiber: ingredient.fiberPer100g,
            calories:
                ingredient.netKcalPer100g ??
                calculateNetKcalPer100g(
                  carbsPer100g: ingredient.carbsPer100g,
                  fiberPer100g: ingredient.fiberPer100g,
                  fatPer100g: ingredient.fatPer100g,
                  proteinPer100g: ingredient.proteinPer100g,
                  labelMode: ingredient.carbsLabelMode,
                ),
            showEnergy: false,
          ),
          if (reference) ...[
            const SizedBox(height: 16),
            LabelValueRow(
              label: lang.ingredientExtendedCarbsLabel,
              value:
                  '${number.format(referenceExtendedCarbsPer100g(fatPer100g: ingredient.fatPer100g, proteinPer100g: ingredient.proteinPer100g))} g',
            ),
            const SizedBox(height: 8),
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
