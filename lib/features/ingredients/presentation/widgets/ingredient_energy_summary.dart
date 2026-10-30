import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/label_value_row.dart';
import '../../data/models/ingredient_details_data.dart';

class IngredientEnergySummary extends StatelessWidget {
  const IngredientEnergySummary({super.key, required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    String energy(double? value) =>
        value == null ? '—' : '${number.format(value)} kcal';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabelValueRow(
          label: lang.mealCaloriesLabel,
          value: energy(ingredient.kcalPer100g),
          emphasized: true,
        ),
        const Divider(height: 12),
        LabelValueRow(
          label: lang.ingredientNetShort,
          value: energy(ingredient.netKcalPer100g),
        ),
        LabelValueRow(
          label: lang.mealWbtLabel,
          value: energy(ingredient.wbtKcalPer100g),
        ),
        LabelValueRow(
          label: lang.ingredientGiLabel,
          value: ingredient.ig == null ? '—' : number.format(ingredient.ig),
        ),
      ],
    );
  }
}
