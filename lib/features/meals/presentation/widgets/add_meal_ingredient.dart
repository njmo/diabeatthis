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
                  'Wyszukaj składnik',
                  Icon(Icons.add_box),
                  addingStateNotifier,
                ),
              AddMealIngredientStage.ingredientForm =>
                _textWithSearchTransition(
                  'Dodaj składnik',
                  Icon(Icons.search),
                  addingStateNotifier,
                ),
              AddMealIngredientStage.portionAddNewSearch =>
                _textWithSearchTransition(
                  'Wybierz porcję dla składnika',
                  Icon(Icons.add),
                  addingStateNotifier,
                ),
              AddMealIngredientStage.definedPortionsSearch =>
                _textWithSearchTransition(
                  'Wyszukaj istniejącą porcję',
                  Icon(Icons.add_box),
                  addingStateNotifier,
                ),
              AddMealIngredientStage.amountForm => Text('Ilość'),
              AddMealIngredientStage.summary => Text('Podsumowanie'),
              AddMealIngredientStage.portionSpecifyAmount => Text(
                'Waga składnika w porcji',
              ),
              AddMealIngredientStage.portionAddNewForm =>
                _textWithSearchTransition(
                  'Dodaj nową porcję',
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
                        ? Text('Dodaj')
                        : Text('Dalej'),
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
                          child: Text('Dodaj w gramach'),
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
                                title: const Text('Odrzucić zmiany?'),
                                content: const Text(
                                  'Czy na pewno chcesz odrzucić zmiany?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(true);
                                    },
                                    child: Text('Tak'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(false);
                                    },
                                    child: Text('Nie'),
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
                          child: Text('Odrzuć'),
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
