import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meals/data/providers/meal_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';

class MealIngredientsList extends ConsumerWidget {
  const MealIngredientsList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealDraft = ref.watch(mealDraftProvider.notifier);
    final mealIngredientDrafts = ref.watch(mealDraftIngredientsProvider);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: mealIngredientDrafts.isEmpty
          ? const Text('No ingredients added')
          : ListView.builder(
              itemBuilder: (context, index) {
                final draft = mealIngredientDrafts[index];
                return ListTile(
                  title: Text(draft.ingredient.name),
                  subtitle: Text(
                    '${draft.ingredientPortion.portion.name} : ${draft.amount}${draft.ingredientPortion.portion.unitHint}',
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      mealDraft.removeMealIngredient(draft);
                    },
                    icon: const Icon(Icons.delete, size: 15),
                  ),
                );
              },
              itemCount: mealIngredientDrafts.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
    );
  }
}
