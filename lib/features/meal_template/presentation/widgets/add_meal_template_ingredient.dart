import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../ingredients/presentation/widgets/ingredient_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_portion_amount_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_search.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../../meals/presentation/widgets/summary.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../../portions/presentation/widgets/portion_form.dart';
import '../../../portions/presentation/widgets/portion_search.dart';
import '../../data/provider/add_meal_template_ingredients_provider.dart';
import '../../data/provider/meal_template_draft_provider.dart';
import 'amount_template_form.dart';

class AddMealTemplateIngredient extends ConsumerWidget {
  const AddMealTemplateIngredient({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(portionFilterProvider);
    final addingStage = ref.watch(addMealTemplateIngredientStageProvider);
    final addingStateNotifier = ref.read(
      addMealTemplateIngredientStageProvider.notifier,
    );

    return Padding(
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
              AddMealTemplateIngredientStage.ingredientSearch =>
                  _textWithSearchTransition(
                    'Ingredient search',
                    Icon(Icons.add_box),
                    addingStateNotifier,
                  ),
              AddMealTemplateIngredientStage.ingredientForm =>
                  _textWithSearchTransition(
                    'Ingredient form',
                    Icon(Icons.search),
                    addingStateNotifier,
                  ),
              AddMealTemplateIngredientStage.portionAddNewSearch =>
                  _textWithSearchTransition(
                    'Portion add new portion to ingredient',
                    Icon(Icons.add),
                    addingStateNotifier,
                  ),
              AddMealTemplateIngredientStage.definedPortionsSearch =>
                  _textWithSearchTransition(
                    'Portion search existing portions',
                    Icon(Icons.add_box),
                    addingStateNotifier,
                  ),
              AddMealTemplateIngredientStage.amountForm => Text('Amount form'),
              AddMealTemplateIngredientStage.summary => Text('Summary'),
              AddMealTemplateIngredientStage.portionSpecifyAmount => Text(
                'Ingredient amount in portion',
              ),
              AddMealTemplateIngredientStage.portionAddNewForm =>
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
                AddMealTemplateIngredientStage.ingredientSearch => IngredientSearch(),
                AddMealTemplateIngredientStage.ingredientForm => IngredientForm(),
                AddMealTemplateIngredientStage.portionAddNewSearch => PortionSearch(),
                AddMealTemplateIngredientStage.definedPortionsSearch => PortionSearch(),
                AddMealTemplateIngredientStage.amountForm => AmountTemplateForm(),
                AddMealTemplateIngredientStage.summary => AddIngredientSummary(),
                AddMealTemplateIngredientStage.portionSpecifyAmount =>
                    IngredientPortionAmountForm(),
                AddMealTemplateIngredientStage.portionAddNewForm => PortionForm(),
              },
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (addingStage == AddMealTemplateIngredientStage.summary) {
                        Navigator.of(
                          context,
                        ).pop(ref.read(mealTemplateIngredientsDraftProvider));
                      } else {
                        final formKey = ref.read(mealIngredientFormKeyProvider);
                        if (formKey.currentState!.validate()) {
                          addingStateNotifier.nextStage();
                          formKey.currentState!.reset();
                        }
                      }
                    },
                    child: (addingStage == AddMealTemplateIngredientStage.summary)
                        ? Text('Add')
                        : Text('Next'),
                  ),
                ),
                addingStage != AddMealTemplateIngredientStage.definedPortionsSearch &&
                    addingStage !=
                        AddMealTemplateIngredientStage.portionAddNewSearch
                    ? SizedBox.shrink()
                    : Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      addingStateNotifier.setOverride();
                    },
                    child: Text('Add by grams'),
                  ),
                ),
                addingStage != AddMealTemplateIngredientStage.summary
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
    );
  }

  Widget _textWithSearchTransition(
      String text,
      Icon icon,
      AddMealTemplateIngredientStageNotifier notifier,
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
