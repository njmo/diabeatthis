import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../data/providers/ingredient_provider.dart';
import 'ingredient_barcode_form_field.dart';
import 'ingredient_macro_form.dart';
import 'ingredient_reference_macro_form.dart';
import 'reference_ingredient_checkbox.dart';

const int _ingredientNameMaxLength = 120;

class IngredientForm extends ConsumerWidget {
  final bool showReferenceToggle;

  const IngredientForm({super.key, this.showReferenceToggle = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = ref.watch(ingredientFormKeyProvider);
    final draft = ref.read(ingredientDraftProvider.notifier);
    final state = ref.watch(ingredientDraftProvider);

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.always,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showReferenceToggle) ...[
            const ReferenceIngredientCheckbox(),
            const SizedBox(height: 16),
          ],
          TextFormField(
            initialValue: draft.getName(),
            maxLength: _ingredientNameMaxLength,
            onChanged: draft.setName,
            validator: _validateName,
            decoration: InputDecoration(
              labelText: context.lang.mealTemplateNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          TextFormField(
            initialValue: draft.getBrand(),
            maxLength: 30,
            onChanged: draft.setBrand,
            validator: _validateOptionalBrand,
            decoration: InputDecoration(
              labelText: context.lang.ingredientBrandLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          if (!state.isReference) ...[
            const IngredientBarcodeFormField(),
            const SizedBox(height: 16),
          ],
          ConfidenceSlider(
            value: ConfidenceLevelX.fromDouble01(state.nutritionConfidence),
            onChanged: draft.setNutritionConfidence,
          ),
          const SizedBox(height: 16),
          if (state.isReference)
            const IngredientReferenceMacroForm()
          else
            const IngredientMacroForm(),
        ],
      ),
    );
  }
}

String? _validateName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return lang.ingredientNameRequired;
  }
  if (name.length < 2) {
    return lang.ingredientNameTooShort;
  }
  return null;
}

String? _validateOptionalBrand(String? value) {
  if ((value == null) || (value.isEmpty) || (value.length < 2)) {
    return '';
  }
  return null;
}
