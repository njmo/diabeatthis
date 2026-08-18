import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../data/providers/ingredient_provider.dart';

class ReferenceIngredientCheckbox extends HookConsumerWidget {
  const ReferenceIngredientCheckbox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ingredientDraftProvider);
    final draft = ref.read(ingredientDraftProvider.notifier);
    final mealIngredientsDraft = ref.watch(
      mealIngredientsDraftProvider.notifier,
    );

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.lang.ingredientReferenceDishTitle),
      subtitle: Text(context.lang.ingredientReferenceDishSubtitle),
      value: state.isReference, // <-- bool w Twoim stanie
      onChanged: (checked) {
        final v = checked ?? false;

        draft.setIsReference(v);

        if (v) {
          draft.setNutritionConfidence(ConfidenceLevel.low);
          mealIngredientsDraft.setQuantityConfidence(ConfidenceLevel.low);
          mealIngredientsDraft.setIngredientPortion(PortionSelection.empty());
        }
      },
    );
  }
}
