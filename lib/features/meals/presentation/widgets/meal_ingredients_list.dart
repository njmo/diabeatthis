import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/providers/portion_provider.dart';
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
                var portionAmount = draft.ingredientPortion.amount;
                final amount = draft.amount;
                if(portionAmount == 0)
                  {
                    portionAmount = ref.watch(
                        gramsPerPortionProvider(
                          draft.ingredient,
                          draft.ingredientPortion.portion,
                        )).when(data: (value) => value!, error: (error, stackTrace) => 0, loading: () => 0);
                  }

                final subtitle = draft.ingredientPortion.portion.when(
                  draft: (name, hint) => Text('$amount of $name : ${portionAmount * amount}$hint'),
                  existing: (id, name, hint) { if(portionAmount == 0) {
                    return CircularProgressIndicator();
                  } else {
                    return Text('$amount of $name : ${amount * portionAmount}$hint');
                  }},
                  empty: () => Text('${amount}g'),
                );

                return Card(
                  child: ListTile(
                    title: Text(draft.ingredient.name),
                    subtitle: subtitle,
                    trailing: IconButton(
                      onPressed: () {
                        mealDraft.removeMealIngredient(draft);
                      },
                      icon: const Icon(Icons.delete, size: 15),
                    ),
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
