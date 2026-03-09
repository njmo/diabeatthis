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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            switch (addingStage) {
              AddMealIngredientStage.ingredientSearch =>
                _textWithSearchTransition(
                  'Ingredient search',
                  Icon(Icons.add_box),
                  addingStateNotifier,
                ),
              AddMealIngredientStage.ingredientForm =>
                _textWithSearchTransition(
                  'Ingredient form',
                  Icon(Icons.search),
                  addingStateNotifier,
                ),
              AddMealIngredientStage.portionAddNewSearch =>
                _textWithSearchTransition(
                  'Portion add new portion to ingredient',
                  Icon(Icons.add),
                  addingStateNotifier,
                ),
              AddMealIngredientStage.definedPortionsSearch =>
                _textWithSearchTransition(
                  'Portion search existing portions',
                  Icon(Icons.add_box),
                  addingStateNotifier,
                ),
              AddMealIngredientStage.amountForm => Text('Amount form'),
              AddMealIngredientStage.summary => Text('Summary'),
              AddMealIngredientStage.portionSpecifyAmount => Text(
                'Ingredient amount in portion',
              ),
              AddMealIngredientStage.portionAddNewForm =>
                _textWithSearchTransition(
                  'Portion add new portion',
                  Icon(Icons.search),
                  addingStateNotifier,
                ),
            },
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: switch (addingStage) {
                AddMealIngredientStage.ingredientSearch => IngredientSearch(),
                AddMealIngredientStage.ingredientForm => IngredientForm(),
                AddMealIngredientStage.portionAddNewSearch => PortionSearch(),
                AddMealIngredientStage.definedPortionsSearch => PortionSearch(),
                AddMealIngredientStage.amountForm => AmountForm(),
                AddMealIngredientStage.summary => AddIngredientSummary(),
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
                        Navigator.of(
                          context,
                        ).pop(ref.read(mealIngredientsDraftProvider));
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
                addingStage != AddMealIngredientStage.definedPortionsSearch &&
                        addingStage !=
                            AddMealIngredientStage.portionAddNewSearch
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
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
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

  Widget _textWithSearchTransition(
    String text,
    Icon icon,
    AddMealIngredientStageNotifier notifier,
  ) {
    return Row(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            onPressed: () => notifier.back(),
            icon: Icon(Icons.arrow_back),
          ),
        ),
        Expanded(child: Text(text)),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => notifier.toOppositeStage(),
            icon: icon,
          ),
        ),
      ],
    );
  }
}
