import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/widgets/form_section.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../data/providers/ingredient_provider.dart';
import 'ingredient_barcode_form_field.dart';
import 'ingredient_icon_button.dart';
import 'ingredient_macro_form.dart';
import 'ingredient_reference_macro_form.dart';
import 'reference_ingredient_checkbox.dart';

const int _ingredientNameMaxLength = 120;

class IngredientForm extends ConsumerWidget {
  final bool showReferenceToggle;
  final bool sectioned;

  const IngredientForm({
    super.key,
    this.showReferenceToggle = true,
    this.sectioned = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = ref.watch(ingredientFormKeyProvider);
    final draft = ref.read(ingredientDraftProvider.notifier);
    final state = ref.watch(ingredientDraftProvider);

    final iconButton = IngredientIconButton(
      editablePreview: sectioned,
      name: state.name,
      brand: state.brand,
      assetPath: state.iconAssetPath,
      onSelected: (path) =>
          draft.overrideDraft(state.copyWith(iconAssetPath: path)),
    );
    final nameField = TextFormField(
      initialValue: draft.getName(),
      maxLength: _ingredientNameMaxLength,
      minLines: 1,
      maxLines: sectioned ? 3 : 1,
      onChanged: draft.setName,
      validator: _validateName,
      decoration: InputDecoration(
        labelText: context.lang.mealTemplateNameLabel,
        counterText: sectioned ? '' : null,
        border: const OutlineInputBorder(),
      ),
    );
    final identityFields = <Widget>[
      if (sectioned)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            iconButton,
            const SizedBox(width: 14),
            Expanded(child: nameField),
          ],
        )
      else ...[
        Align(alignment: Alignment.centerLeft, child: iconButton),
        const SizedBox(height: 8),
        nameField,
      ],
      if (sectioned) const SizedBox(height: 16),
      TextFormField(
        initialValue: draft.getBrand(),
        maxLength: 30,
        onChanged: draft.setBrand,
        validator: _validateOptionalBrand,
        decoration: InputDecoration(
          counterText: sectioned ? '' : null,
          labelText: sectioned && state.isReference
              ? context.lang.ingredientReferenceBrandOptional
              : context.lang.ingredientBrandOptionalLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      if (!state.isReference) ...[
        if (sectioned) const SizedBox(height: 16),
        IngredientBarcodeFormField(compact: sectioned),
        const SizedBox(height: 16),
      ],
    ];
    final nutritionFields = <Widget>[
      ConfidenceSlider(
        value: ConfidenceLevelX.fromDouble01(state.nutritionConfidence),
        onChanged: draft.setNutritionConfidence,
      ),
      const SizedBox(height: 16),
      if (state.isReference)
        IngredientReferenceMacroForm(responsive: sectioned)
      else
        IngredientMacroForm(compact: sectioned),
    ];
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUnfocus,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showReferenceToggle) ...[
            const ReferenceIngredientCheckbox(),
            const SizedBox(height: 16),
          ],
          if (sectioned) ...[
            SectionSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: identityFields,
              ),
            ),
            const SizedBox(height: 16),
            SectionSurface(
              child: FormSection(
                title: state.isReference
                    ? context.lang.ingredientReferenceValues
                    : context.lang.ingredientNutritionValues,
                children: nutritionFields,
              ),
            ),
          ] else ...[
            ...identityFields,
            ...nutritionFields,
          ],
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
  final brand = value?.trim() ?? '';
  if (brand.isEmpty) return null;
  return brand.length < 2 ? lang.ingredientBrandTooShort : null;
}
