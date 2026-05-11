import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../../meals/presentation/widgets/meal_ingredient_preview_tile.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../controllers/meal_summary_controller.dart';
import '../utils/meal_summary_extra_item_portion_resolver.dart';

class MealSummaryExtraItemsSection extends ConsumerWidget {
  const MealSummaryExtraItemsSection({
    super.key,
    required this.mealId,
    required this.items,
  });

  final int mealId;
  final List<MealIngredientsDraft> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mealSummaryControllerProvider(mealId).notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dokładka', style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Dodaj coś, czego nie było w planie posiłku.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _addExtraItem(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Brak dokładki. Jeśli dziecko dojadło coś ekstra, dodaj to tutaj.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final item in items)
            MealIngredientPreviewTile(
              draft: item,
              onEdit: () => _editExtraItem(context, ref, item),
              onRemove: () => notifier.removeExtraItem(item),
            ),
      ],
    );
  }

  Future<void> _addExtraItem(BuildContext context, WidgetRef ref) async {
    final mealIngredient = await showModalBottomSheet<MealIngredientsDraft>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      builder: (_) => const AddMealIngredient(),
    );

    if (mealIngredient != null) {
      final resolvedMealIngredient =
          await resolveMealSummaryExtraItemPortionAmount(
            item: mealIngredient,
            loadPortionAmount: () => ref.read(
              gramsPerPortionProvider(
                mealIngredient.ingredient,
                mealIngredient.ingredientPortion.portion,
              ).future,
            ),
          );

      ref
          .read(mealSummaryControllerProvider(mealId).notifier)
          .addExtraItem(resolvedMealIngredient);
    }
  }

  Future<void> _editExtraItem(
    BuildContext context,
    WidgetRef ref,
    MealIngredientsDraft item,
  ) async {
    ref
        .read(mealIngredientsDraftProvider.notifier)
        .overrideMealIngredient(item);
    ref
        .read(addMealIngredientStageProvider.notifier)
        .modifyIngredientStage(item.ingredient.isReference);

    final mealIngredient = await showModalBottomSheet<MealIngredientsDraft>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      builder: (_) => const AddMealIngredient(),
    );

    if (mealIngredient != null) {
      final resolvedMealIngredient =
          await resolveMealSummaryExtraItemPortionAmount(
            item: mealIngredient,
            loadPortionAmount: () => ref.read(
              gramsPerPortionProvider(
                mealIngredient.ingredient,
                mealIngredient.ingredientPortion.portion,
              ).future,
            ),
          );

      ref
          .read(mealSummaryControllerProvider(mealId).notifier)
          .replaceExtraItem(item, resolvedMealIngredient);
    }
  }
}
