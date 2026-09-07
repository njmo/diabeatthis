import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/models/meal_ingredient_replacement_result.dart';
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
    final mealIngredient = await showAddMealIngredientSheet(
      context: context,
      ref: ref,
      initialDraft: draft,
    );
    if (mealIngredient != null && context.mounted) {
      final mealDraft = ref.read(mealDraftProvider.notifier);
      final result = mealDraft.replaceMealIngredient(draft, mealIngredient);
      if (result == MealIngredientReplacementResult.duplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.mealIngredientAlreadyOnList)),
        );
      }
    }
  }
}
