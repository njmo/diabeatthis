import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/drafts/ingredient_draft.dart';
import '../../data/drafts/ingredient_draft_validation.dart';
import '../../data/providers/ingredient_provider.dart';
import '../utils/reference_ingredient_macro_calculator.dart';
import 'nutrition_value_text_form_field.dart';

class IngredientReferenceMacroForm extends HookConsumerWidget {
  const IngredientReferenceMacroForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredient = ref.watch(ingredientDraftProvider);
    final draft = ref.read(ingredientDraftProvider.notifier);
    final extendedCarbs = referenceExtendedCarbsPer100g(
      fatPer100g: ingredient.fatPer100g,
      proteinPer100g: ingredient.proteinPer100g,
    );
    final extendedCarbsController = useTextEditingController(
      text: formatReferenceMacroInput(extendedCarbs),
    );
    final fatShare = referenceFatShare(
      fatPer100g: ingredient.fatPer100g,
      proteinPer100g: ingredient.proteinPer100g,
    );
    final safeFatShare = fatShare.clamp(0.0, 1.0);
    final fatPercent = (safeFatShare * 100).round();
    final proteinPercent = 100 - fatPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: NutritionValueTextFormField(
                label: context.lang.ingredientSimpleCarbsLabel,
                initialValue: formatReferenceMacroInput(
                  ingredient.carbsPer100g,
                ),
                icon: Icons.grain,
                onChanged: draft.setCarbsPer100g,
                validator: (value) =>
                    _validateRequiredEnergyMacro(value, ingredient),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NutritionValueTextFormField(
                label: context.lang.ingredientExtendedCarbsLabel,
                controller: extendedCarbsController,
                icon: Icons.schedule,
                onChanged: (value) {
                  final ecarbs = parseReferenceMacroInput(value);
                  draft.setFatPer100g(
                    formatReferenceMacroInput(
                      referenceFatPer100g(
                        extendedCarbsPer100g: ecarbs,
                        fatShare: fatShare,
                      ),
                    ),
                  );
                  draft.setProteinPer100g(
                    formatReferenceMacroInput(
                      referenceProteinPer100g(
                        extendedCarbsPer100g: ecarbs,
                        fatShare: fatShare,
                      ),
                    ),
                  );
                },
                validator: _validateRequiredMacro,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.lang.ingredientEcarbsSplit(proteinPercent, fatPercent),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Slider(
          value: safeFatShare,
          min: 0,
          max: 1,
          divisions: 20,
          label: context.lang.ingredientFatPercentLabel(fatPercent),
          onChanged: (value) {
            final ecarbs = parseReferenceMacroInput(
              extendedCarbsController.text,
            );
            draft.setFatPer100g(
              formatReferenceMacroInput(
                referenceFatPer100g(
                  extendedCarbsPer100g: ecarbs,
                  fatShare: value,
                ),
              ),
            );
            draft.setProteinPer100g(
              formatReferenceMacroInput(
                referenceProteinPer100g(
                  extendedCarbsPer100g: ecarbs,
                  fatShare: value,
                ),
              ),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.lang.mealProteinLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              context.lang.mealFatLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

String? _validateRequiredEnergyMacro(
  String? value,
  IngredientDraft ingredient,
) {
  final valueError = _validateRequiredMacro(value);
  if (valueError != null) {
    return valueError;
  }
  if (!ingredient.hasEnergyMacros) {
    return lang.ingredientReferenceMacroRequired;
  }
  return null;
}

String? _validateRequiredMacro(String? value) {
  final normalized = value?.trim().replaceAll(',', '.');
  if (normalized == null || normalized.isEmpty) {
    return lang.ingredientNumberRequired;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0) {
    return lang.ingredientNumberRequired;
  }
  return null;
}
