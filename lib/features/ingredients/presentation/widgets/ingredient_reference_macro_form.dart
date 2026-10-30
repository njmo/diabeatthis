import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../data/drafts/ingredient_draft.dart';
import '../../data/drafts/ingredient_draft_validation.dart';
import '../../data/providers/ingredient_provider.dart';
import '../utils/reference_ingredient_macro_calculator.dart';
import 'nutrition_value_text_form_field.dart';

class IngredientReferenceMacroForm extends HookConsumerWidget {
  const IngredientReferenceMacroForm({super.key, this.responsive = false});

  final bool responsive;

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

    final fields = <Widget>[
      NutritionValueTextFormField(
        compact: responsive,
        label: context.lang.ingredientSimpleCarbsLabel,
        initialValue: formatReferenceMacroInput(ingredient.carbsPer100g),
        icon: Icons.grain,
        onChanged: draft.setCarbsPer100g,
        validator: (value) => _validateRequiredEnergyMacro(value, ingredient),
      ),
      NutritionValueTextFormField(
        compact: responsive,
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
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (responsive)
          ResponsiveMetricList(
            maxColumns: 2,
            minimumWidth: 230,
            children: fields,
          )
        else
          Row(
            children: [
              Expanded(child: fields[0]),
              const SizedBox(width: 10),
              Expanded(child: fields[1]),
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
            Expanded(
              child: Text(
                context.lang.mealProteinLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.lang.mealFatLabel,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
