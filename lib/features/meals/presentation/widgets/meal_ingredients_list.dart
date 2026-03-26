import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import 'add_meal_ingredient.dart';

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
                if (!draft.ingredient.isReference && portionAmount == 0) {
                  portionAmount = ref
                      .watch(
                        gramsPerPortionProvider(
                          draft.ingredient,
                          draft.ingredientPortion.portion,
                        ),
                      )
                      .when(
                        data: (value) => value!,
                        error: (error, stackTrace) => 0,
                        loading: () => 0,
                      );
                }

                final subtitle = draft.ingredientPortion.portion.when(
                  draft: (name, hint) =>
                      Text('$amount of $name : ${portionAmount * amount}$hint'),
                  existing: (id, name, hint) {
                    if (portionAmount == 0) {
                      return CircularProgressIndicator();
                    } else {
                      return Text(
                        '$amount of $name : ${amount * portionAmount}$hint',
                      );
                    }
                  },
                  empty: () => draft.ingredient.isReference
                      ? Text('$amount referencyjne porcje')
                      : Text('${amount}g'),
                );

                return Card(
                  child: ListTile(
                    title: Text(draft.ingredient.name),
                    subtitle: subtitle,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            mealDraft.removeMealIngredient(draft);
                          },
                          icon: const Icon(Icons.delete, size: 15),
                        ),
                        IconButton(
                          onPressed: () async {
                            final addingStateNotifier = ref.watch(
                              addMealIngredientStageProvider.notifier,
                            );
                            final mealIngredientDraft = ref.watch(
                              mealIngredientsDraftProvider.notifier,
                            );
                            mealIngredientDraft.overrideMealIngredient(draft);
                            addingStateNotifier.modifyIngredientStage(draft.ingredient.isReference);

                            final mealIngredient =
                                await showModalBottomSheet<MealIngredientsDraft>(
                              context: context,
                              useRootNavigator: false,
                              isScrollControlled: true,
                              builder: (_) => AddMealIngredient(),
                            );
                            if (mealIngredient != null) {
                              mealDraft.removeMealIngredient(draft);
                              mealDraft.addMealIngredient(mealIngredient);
                            }
                          },
                          icon: const Icon(Icons.edit, size: 15),
                        ),
                      ],
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
