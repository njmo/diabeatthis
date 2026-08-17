import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../data/drafts/ingredient_draft.dart';
import '../../data/drafts/ingredient_draft_validation.dart';
import '../../data/providers/ingredient_provider.dart';
import 'nutrition_value_text_form_field.dart';

class IngredientMacroForm extends ConsumerWidget {
  const IngredientMacroForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.read(ingredientDraftProvider.notifier);
    final value = ref.watch(ingredientDraftProvider);
    final canChangeLabelMode = value.map(
      draft: (_) => true,
      existing: (_) => false,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Makro na 100 g',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            SegmentedButton<CarbsLabelMode>(
              segments: const [
                ButtonSegment(value: CarbsLabelMode.eu, label: Text('UE')),
                ButtonSegment(
                  value: CarbsLabelMode.nonEu,
                  label: Text('non-UE'),
                ),
              ],
              selected: {value.carbsLabelMode},
              onSelectionChanged: canChangeLabelMode
                  ? (selected) {
                      draft.setCarbsLabelMode(selected.single);
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: NutritionValueTextFormField(
                label: 'Węglowodany',
                initialValue: _formatInput(value.carbsPer100g),
                onChanged: draft.setCarbsPer100g,
                validator: (input) =>
                    _validateMacroInput(input) ??
                    _macroValidationMessage(value),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NutritionValueTextFormField(
                label: 'Tłuszcz',
                initialValue: _formatInput(value.fatPer100g),
                onChanged: draft.setFatPer100g,
                validator: _validateMacroInput,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: NutritionValueTextFormField(
                label: 'Białko',
                initialValue: _formatInput(value.proteinPer100g),
                onChanged: draft.setProteinPer100g,
                validator: _validateMacroInput,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NutritionValueTextFormField(
                label: 'Błonnik',
                initialValue: _formatInput(value.fiberPer100g),
                onChanged: draft.setFiberPer100g,
                validator: (input) =>
                    _validateMacroInput(input) ??
                    _netCarbsValidationMessage(value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String? _macroValidationMessage(IngredientDraft value) {
  if (!value.hasEnergyMacros) {
    return 'Uzupełnij węglowodany, tłuszcz albo białko';
  }
  return _netCarbsValidationMessage(value);
}

String? _netCarbsValidationMessage(IngredientDraft value) {
  if (!value.hasPositiveNonEuNetCarbs) {
    return 'Węglow. > błonnik';
  }
  return null;
}

String? _validateMacroInput(String? value) {
  final normalized = value?.trim().replaceAll(',', '.');
  if (normalized == null || normalized.isEmpty) {
    return '';
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0) {
    return 'Podaj liczbę';
  }
  if (parsed > IngredientDraftValidation.maxMacroPer100g) {
    return 'Maks. 100 g/100 g';
  }
  return null;
}

String _formatInput(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
