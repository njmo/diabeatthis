import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/widgets/confidence_slider.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../../meals/presentation/widgets/meal_ingredient_preview_tile.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../controllers/meal_summary_controller.dart';
import '../utils/add_meal_summary_extra_item.dart';
import '../utils/meal_summary_extra_item_portion_resolver.dart';

class MealSummaryExtraItemsSection extends ConsumerWidget {
  const MealSummaryExtraItemsSection({
    super.key,
    required this.mealId,
    required this.items,
    this.showConfidence = false,
    this.onAddFood,
  });

  final int mealId;
  final List<MealIngredientsDraft> items;
  final bool showConfidence;
  final VoidCallback? onAddFood;

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
                  Text(
                    context.lang.mealSummaryExtraTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.lang.mealSummaryExtraSubtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed:
                  onAddFood ??
                  () => addMealSummaryExtraItem(
                    context: context,
                    ref: ref,
                    mealId: mealId,
                  ),
              icon: const Icon(Icons.add),
              label: Text(context.lang.mealSummaryExtraAdd),
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
                context.lang.mealSummaryExtraEmpty,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final item in items) ...[
            MealIngredientPreviewTile(
              draft: item,
              onEdit: () => _editExtraItem(context, ref, item),
              onRemove: () => notifier.removeExtraItem(item),
            ),
            if (showConfidence)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: ConfidenceSlider(
                  title: context.lang.mealSummaryConfidenceQuestion,
                  value: ConfidenceLevelX.fromDouble01(
                    item.consumedConfidence ?? item.quantityConfidence,
                  ),
                  onChanged: (value) => notifier.replaceExtraItem(
                    item,
                    item.copyWith(
                      consumedConfidence: value.toDouble01(),
                      quantityConfidence: value.toDouble01(),
                    ),
                  ),
                ),
              ),
          ],
      ],
    );
  }

  Future<void> _editExtraItem(
    BuildContext context,
    WidgetRef ref,
    MealIngredientsDraft item,
  ) async {
    ref.read(addMealIngredientStageProvider.notifier).editIngredient(item);

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
