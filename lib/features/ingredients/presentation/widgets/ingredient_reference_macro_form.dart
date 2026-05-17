import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
                label: 'Węglowodany proste (carbs)',
                initialValue: formatReferenceMacroInput(
                  ingredient.carbsPer100g,
                ),
                icon: Icons.grain,
                onChanged: draft.setCarbsPer100g,
                validator: _validateRequiredMacro,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NutritionValueTextFormField(
                label: 'Węglowodany przedłużone (ecarbs)',
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
          'Podział ecarbs: białko $proteinPercent% / tłuszcz $fatPercent%',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Slider(
          value: safeFatShare,
          min: 0,
          max: 1,
          divisions: 20,
          label: '$fatPercent% tłuszcz',
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
            Text('Białko', style: Theme.of(context).textTheme.bodySmall),
            Text('Tłuszcz', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

String? _validateRequiredMacro(String? value) {
  final normalized = value?.trim().replaceAll(',', '.');
  if (normalized == null || normalized.isEmpty) {
    return 'Podaj liczbę';
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0) {
    return 'Podaj liczbę';
  }
  return null;
}
