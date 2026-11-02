import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../dashboard/presentation/widgets/nutrient_summary_chart.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import 'add_meal_ingredient.dart';
import 'meal_ingredients_empty_state.dart';
import 'meal_ingredients_list.dart';

class MealIngredientsListEditor extends ConsumerWidget {
  const MealIngredientsListEditor({
    super.key,
    this.showNutritionSummary = true,
    this.compact = false,
  });
  final bool showNutritionSummary;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculatedMacronutrients = showNutritionSummary
        ? ref.watch(calculatedMacronutrientsProvider)
        : null;
    final ingredientDrafts = ref.watch(mealDraftIngredientsProvider);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ingredientDrafts.isEmpty
                      ? context.lang.mealIngredientsListTitle
                      : context.lang.mealIngredientsListCountTitle(
                          ingredientDrafts.length,
                        ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.filled(
                tooltip: context.lang.mealAddFirstIngredient,
                onPressed: () => _addIngredient(context, ref),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (ingredientDrafts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const MealIngredientsList(),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (calculatedMacronutrients != null)
          calculatedMacronutrients.when(
            data: (value) => NutrientSummaryChart(macros: value),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text(context.lang.mealIngredientsLoadError(err)),
          ),
        const SizedBox(height: 16),
        Text(
          ingredientDrafts.isEmpty
              ? context.lang.mealIngredientsListTitle
              : context.lang.mealIngredientsListCountTitle(
                  ingredientDrafts.length,
                ),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (ingredientDrafts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _addIngredient(context, ref),
              icon: const Icon(Icons.add),
              label: Text(context.lang.mealAddNextIngredient),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ingredientDrafts.isEmpty
            ? MealIngredientsEmptyState(
                onAdd: () => _addIngredient(context, ref),
              )
            : const MealIngredientsList(),
      ],
    );
  }

  Future<void> _addIngredient(BuildContext context, WidgetRef ref) async {
    final mealIngredient = await showAddMealIngredientSheet(
      context: context,
      ref: ref,
    );
    if (mealIngredient != null) {
      final added = ref
          .read(mealDraftProvider.notifier)
          .addMealIngredient(mealIngredient);
      if (!added && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.mealIngredientAlreadyOnList)),
        );
      }
    }
  }
}
