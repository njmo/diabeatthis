import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/nutrition_value_text_form_field.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../data/providers/ingredient_provider.dart';
import 'reference_ingredient_checkbox.dart';

const int _ingredientNameMaxLength = 120;

class IngredientForm extends ConsumerWidget {
  const IngredientForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.read(ingredientDraftProvider.notifier);
    final state = ref.watch(ingredientDraftProvider);
    final formKey = ref.watch(mealIngredientFormKeyProvider);

    return SingleChildScrollView(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.always,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ReferenceIngredientCheckbox(),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: draft.getName(),
              maxLength: _ingredientNameMaxLength,
              onChanged: draft.setName,
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) {
                  return 'Podaj nazwę składnika';
                }
                if (name.length < 2) {
                  return 'Nazwa jest za krótka';
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Nazwa',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              initialValue: draft.getBrand(),
              maxLength: 30,
              onChanged: draft.setBrand,
              validator: (value) {
                if ((value == null) || (value.isEmpty) || (value.length < 2)) {
                  return '';
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Producent',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ConfidenceSlider(
              value: ConfidenceLevelX.fromDouble01(state.nutritionConfidence),
              onChanged: draft.setNutritionConfidence,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: NutritionValueTextFormField(
                    label: 'Ilość węglowodanów na 100g',
                    initialValue: draft.getCarbsPer100g(),
                    onChanged: draft.setCarbsPer100g,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NutritionValueTextFormField(
                    label: 'Ilość tłuszczu na 100g',
                    initialValue: draft.getFatPer100g(),
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
                    initialValue: draft.getProteinPer100g(),
                    onChanged: draft.setProteinPer100g,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NutritionValueTextFormField(
                    label: 'Ilość błonnika na 100g',
                    initialValue: draft.getFiberPer100g(),
                    onChanged: draft.setFiberPer100g,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
