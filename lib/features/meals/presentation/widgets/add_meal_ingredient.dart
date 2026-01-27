import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../ingredients/presentation/widgets/ingredient_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_portion_amount_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_search.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../../portions/presentation/widgets/portion_form.dart';
import '../../../portions/presentation/widgets/portion_search.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import 'amount_form.dart';
import 'summary.dart';

class AddMealIngredient extends ConsumerWidget {
  const AddMealIngredient({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(portionFilterProvider);
    final addingStage = ref.watch(addMealIngredientStageProvider);
    final addingStateNotifier = ref.read(
      addMealIngredientStageProvider.notifier,
    );

    if (addingStage == AddMealIngredientStage.completed) {
      Navigator.of(context).pop();
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            switch (addingStage) {
              AddMealIngredientStage.ingredientSearch =>
                _textWithSearchTransition(
                  'Ingredient search',
                  Icon(Icons.add_box),
                  () {
                    addingStateNotifier.toOppositeStage();
                  },
                ),
              AddMealIngredientStage.ingredientForm =>
                _textWithSearchTransition(
                  'Ingredient form',
                  Icon(Icons.search),
                  () {
                    addingStateNotifier.toOppositeStage();
                  },
                ),
              AddMealIngredientStage.portionAddNewSearch =>
                _textWithSearchTransition(
                  'Portion add new portion to ingredient',
                  Icon(Icons.add),
                  () {
                    addingStateNotifier.toOppositeStage();
                  },
                ),
              AddMealIngredientStage.definedPortionsSearch =>
                _textWithSearchTransition(
                  'Portion search existing portions',
                  Icon(Icons.add_box),
                  () {
                    addingStateNotifier.toOppositeStage();
                  },
                ),
              AddMealIngredientStage.amountForm => Text('Amount form'),
              AddMealIngredientStage.summary => Text('Summary'),
              AddMealIngredientStage.completed => throw UnimplementedError(),
              AddMealIngredientStage.portionSpecifyAmount => Text(
                'Ingredient amount in portion',
              ),
              AddMealIngredientStage.portionAddNewForm =>
                _textWithSearchTransition(
                  'Portion add new portion',
                  Icon(Icons.search),
                  () {
                    addingStateNotifier.toOppositeStage();
                  },
                ),
            },
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: switch (addingStage) {
                AddMealIngredientStage.ingredientSearch => IngredientSearch(),
                AddMealIngredientStage.ingredientForm => IngredientForm(),
                AddMealIngredientStage.portionAddNewSearch =>
                  PortionSearch(),
                AddMealIngredientStage.definedPortionsSearch =>
                  PortionSearch(),
                AddMealIngredientStage.amountForm => AmountForm(),
                AddMealIngredientStage.summary => AddIngredientSummary(),
                AddMealIngredientStage.completed => throw UnimplementedError(),
                // TODO: Handle this case.
                AddMealIngredientStage.portionSpecifyAmount =>
                  IngredientPortionAmountForm(),
                AddMealIngredientStage.portionAddNewForm => PortionForm(),
              },
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (addingStage == AddMealIngredientStage.summary) {
                        final mealDraft = ref.read(mealDraftProvider.notifier);
                        mealDraft.addMealIngredient(
                          ref.read(mealIngredientsDraftProvider),
                        );
                        addingStateNotifier.nextStage();
                      } else {
                        final formKey = ref.read(mealIngredientFormKeyProvider);
                        if (formKey.currentState!.validate()) {
                          addingStateNotifier.nextStage();
                          formKey.currentState!.reset();
                        }
                      }
                    },
                    child: (addingStage == AddMealIngredientStage.summary)
                        ? Text('Add')
                        : Text('Next'),
                  ),
                ),
                addingStage != AddMealIngredientStage.definedPortionsSearch && addingStage != AddMealIngredientStage.portionAddNewSearch
                    ? SizedBox.shrink()
                    : Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            addingStateNotifier.setOverride();
                          },
                          child: Text('Add by grams'),
                        ),
                      ),
                addingStage != AddMealIngredientStage.summary
                    ? SizedBox.shrink()
                    : Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Discard changes?'),
                                content: const Text(
                                  'Are you sure you want to discard changes?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(true);
                                    },
                                    child: Text('Yes'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    },
                                    child: Text('No'),
                                  ),
                                ],
                              ),
                            );
                            if (result == true) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text('Discard'),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _textWithSearchTransition(String text, Icon icon, Function f) {
    return Row(
      children: [
        Expanded(child: Text(text)),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => f(),
            icon: icon,
          ),
        ),
      ],
    );
  }
}
