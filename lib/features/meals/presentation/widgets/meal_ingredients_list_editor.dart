import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/presentation/screens/ingredient_form.dart';
import '../../../ingredients/presentation/screens/ingredient_search.dart';
import '../../../meals/data/providers/meal_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/presentation/screens/portion_search.dart';
import '../../data/drafts/meal_draft.dart';
import 'add_meal_ingredient.dart';
import 'meal_ingredients_list.dart';
import 'portion_amount_form.dart';

class MealIngredientsListEditor extends ConsumerWidget {
  const MealIngredientsListEditor({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealDraft = ref.watch(mealDraftProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(

        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Align(
                      alignment: AlignmentGeometry.bottomLeft,
                      child: Text('Ingredients'),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () async {
                        final ingredient =
                            await showModalBottomSheet<IngredientSelection>(
                              context: context,
                              useRootNavigator: false,
                              isScrollControlled: true,
                              isDismissible: false,
                              builder: (_) => AddMealIngredient(),
                            );
                      },
                      child: const Icon(Icons.add_box, size: 20),
                    ),
                    InkWell(
                      onTap: () async {
                        final ingredient =
                            await showModalBottomSheet<IngredientSelection>(
                              context: context,
                              useRootNavigator: false,
                              isScrollControlled: true,
                              isDismissible: false,
                              builder: (_) => IngredientForm(),
                            );
                        if (ingredient != null) {
                          final portion = await showDialog<PortionSelection>(
                            context: context,
                            useRootNavigator: false,
                            barrierDismissible: false,
                            builder: (_) => PortionSearch(),
                          );
                          if (portion == null) {
                            _showSnackBar(
                              context,
                              'Anulowano dodawanie skladnika',
                            );
                            return;
                          }

                          final portionAmount = await showDialog<int>(
                            context: context,
                            useRootNavigator: false,
                            barrierDismissible: false,
                            builder: (_) => PortionAmountForm(),
                          );
                          if (portionAmount == null) {
                            _showSnackBar(
                              context,
                              'Anulowano dodawanie skladnika',
                            );
                            return;
                          }

                          mealDraft.addMealIngredient(
                            MealIngredientsDraft(
                              ingredient: ingredient,
                              ingredientPortion: IngredientPortionDraft(
                                portion: portion,
                                amount: 50,
                              ),
                              amount: portionAmount,
                            ),
                          );
                          _showSnackBar(
                            context,
                            'Dodano składnik: ${ingredient.name}',
                          );
                        } else {
                          // ignore: use_build_context_synchronously
                          _showSnackBar(context, 'Anulowano dodanie składnika');
                        }
                      },
                      child: const Icon(Icons.add_circle, size: 20),
                    ),
                    InkWell(
                      onTap: () async {
                        final mealIngredientsDraftNotifier = ref.read(
                          mealIngredientsDraftProvider.notifier,
                        );
                        final ingredient =
                            await showModalBottomSheet<IngredientSelection>(
                              context: context,
                              useRootNavigator: false,
                              isScrollControlled: true,
                              isDismissible: false,
                              builder: (_) => IngredientSearch(),
                            );
                        if (ingredient == null) {
                          // ignore: use_build_context_synchronously
                          _showSnackBar(context, 'Anulowano dodanie składnika');
                        } else {
                          mealIngredientsDraftNotifier.setIngredient(
                            ingredient,
                          );
                          final portion = await showDialog<PortionSelection>(
                            context: context,
                            useRootNavigator: false,
                            barrierDismissible: false,
                            builder: (_) => PortionSearch(),
                          );
                          if (portion == null) {
                            _showSnackBar(
                              context,
                              'Anulowano dodawanie skladnika',
                            );
                          }

                          final portionAmount = await showDialog<int>(
                            context: context,
                            useRootNavigator: false,
                            barrierDismissible: false,
                            builder: (_) => PortionAmountForm(),
                          );
                          if (portionAmount == null) {
                            _showSnackBar(
                              context,
                              'Anulowano dodawanie skladnika',
                            );
                            return;
                          }

                          mealDraft.addMealIngredient(
                            MealIngredientsDraft(
                              ingredient: ingredient,
                              ingredientPortion: IngredientPortionDraft(
                                portion: portion!,
                                amount: 50,
                              ),
                              amount: portionAmount,
                            ),
                          );
                          // ignore: use_build_context_synchronously
                          _showSnackBar(
                            context,
                            'Wybrano składnik: ${ingredient.name}',
                          );
                        }
                      },
                      child: const Icon(Icons.search, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MealIngredientsList(),
        ],
      ),
    );
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _showSnackBar(
    BuildContext context,
    String message,
  ) {
    return ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
