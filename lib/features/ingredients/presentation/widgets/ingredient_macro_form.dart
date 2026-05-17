import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/ingredient_provider.dart';
import 'nutrition_value_text_form_field.dart';

class IngredientMacroForm extends ConsumerWidget {
  const IngredientMacroForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.read(ingredientDraftProvider.notifier);
    final value = ref.watch(ingredientDraftProvider);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: NutritionValueTextFormField(
                label: 'Ilość węglowodanów na 100g',
                initialValue: _formatInput(value.carbsPer100g),
                onChanged: draft.setCarbsPer100g,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NutritionValueTextFormField(
                label: 'Ilość tłuszczu na 100g',
                initialValue: _formatInput(value.fatPer100g),
                onChanged: draft.setFatPer100g,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: NutritionValueTextFormField(
                label: 'Ilość białka na 100g',
                initialValue: _formatInput(value.proteinPer100g),
                onChanged: draft.setProteinPer100g,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NutritionValueTextFormField(
                label: 'Ilość błonnika na 100g',
                initialValue: _formatInput(value.fiberPer100g),
                onChanged: draft.setFiberPer100g,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatInput(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
