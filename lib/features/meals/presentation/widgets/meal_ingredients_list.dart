import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import 'add_meal_ingredient.dart';
import 'meal_ingredient_preview_tile.dart';

class MealIngredientsList extends ConsumerWidget {
  const MealIngredientsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealDraft = ref.watch(mealDraftProvider.notifier);
    final mealIngredientDrafts = ref.watch(mealDraftIngredientsProvider);

    if (mealIngredientDrafts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (final draft in mealIngredientDrafts)
          MealIngredientPreviewTile(
            draft: draft,
            onRemove: () => mealDraft.removeMealIngredient(draft),
            onEdit: () => _editIngredient(context, ref, draft),
          ),
      ],
    );
  }

  Future<void> _editIngredient(
    BuildContext context,
    WidgetRef ref,
    MealIngredientsDraft draft,
  ) async {
    final addingStateNotifier = ref.watch(
      addMealIngredientStageProvider.notifier,
    );
    final mealIngredientDraft = ref.watch(
      mealIngredientsDraftProvider.notifier,
    );
    mealIngredientDraft.overrideMealIngredient(draft);
    addingStateNotifier.modifyIngredientStage(draft.ingredient.isReference);

    final mealIngredient = await showModalBottomSheet<MealIngredientsDraft>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      builder: (_) => const AddMealIngredient(),
    );
    if (mealIngredient != null) {
      final mealDraft = ref.read(mealDraftProvider.notifier);
      mealDraft.removeMealIngredient(draft);
      mealDraft.addMealIngredient(mealIngredient);
    }
  }
}
