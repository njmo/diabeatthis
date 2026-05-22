import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../dashboard/presentation/widgets/nutrient_summary_chart.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import 'add_meal_ingredient.dart';
import 'meal_ingredients_empty_state.dart';
import 'meal_ingredients_list.dart';

class MealIngredientsListEditor extends ConsumerWidget {
  const MealIngredientsListEditor({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculatedMacronutrients = ref.watch(
      calculatedMacronutrientsProvider,
    );
    final ingredientDrafts = ref.watch(mealDraftIngredientsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        calculatedMacronutrients.when(
          data: (value) => NutrientSummaryChart(macros: value),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Składniki (błąd: $err)'),
        ),
        const SizedBox(height: 16),
        Text(
          ingredientDrafts.isEmpty
              ? 'Lista składników'
              : 'Lista składników (${ingredientDrafts.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (ingredientDrafts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _addIngredient(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj kolejny'),
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
      ref.read(mealDraftProvider.notifier).addMealIngredient(mealIngredient);
    }
  }
}
