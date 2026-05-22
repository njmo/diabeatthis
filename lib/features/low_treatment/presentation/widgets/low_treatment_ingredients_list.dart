import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../../meals/presentation/widgets/meal_ingredient_preview_tile.dart';
import '../controllers/low_treatment_context_controller.dart';

class LowTreatmentIngredientsList extends ConsumerWidget {
  const LowTreatmentIngredientsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(
      lowTreatmentContextControllerProvider.select(
        (state) => state.mealIngredients,
      ),
    );
    final controller = ref.read(lowTreatmentContextControllerProvider.notifier);

    if (ingredients.isEmpty) {
      final theme = Theme.of(context);

      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nie dodano jeszcze składników.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final ingredient in ingredients)
          MealIngredientPreviewTile(
            draft: ingredient,
            onRemove: () => controller.removeMealIngredient(ingredient),
            onEdit: () => _editIngredient(context, ref, ingredient),
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
    if (mealIngredient == null) {
      return;
    }

    ref
        .read(lowTreatmentContextControllerProvider.notifier)
        .updateMealIngredient(draft, mealIngredient);
  }
}
