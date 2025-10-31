import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../ingredients/presentation/screens/ingredient_form.dart';
import '../../../ingredients/presentation/screens/ingredient_search.dart';
import '../../../portions/presentation/screens/portion_form.dart';
import '../../../portions/presentation/screens/portion_search.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';

class AddMealIngredient extends ConsumerWidget {
  const AddMealIngredient({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addingStage = ref.watch(addMealIngredientStageProvider);
    final addingStateNotifier = ref.read(
      addMealIngredientStageProvider.notifier,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (addingStage) {
          AddMealIngredientStage.ingredient_search => _textWithSearchTransition(
            'Ingredient search',
            Icon(Icons.add_box),
            () {
              addingStateNotifier.toOppositeStage();
            },
          ),
          AddMealIngredientStage.ingredient_form => _textWithSearchTransition(
            'Ingredient form',
            Icon(Icons.search),
            () {
              addingStateNotifier.toOppositeStage();
            },
          ),
          AddMealIngredientStage.portion_add => _textWithSearchTransition(
            'Portion add',
            Icon(Icons.search),
            () {
              addingStateNotifier.toOppositeStage();
            },
          ),
          AddMealIngredientStage.portion_search => _textWithSearchTransition(
            'Portion search',
            Icon(Icons.add_box),
            () {
              addingStateNotifier.toOppositeStage();
            },
          ),
          AddMealIngredientStage.amount_form => Text('Amount form'),
          AddMealIngredientStage.completed => Text('Completed'),
        },
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (addingStage) {
            AddMealIngredientStage.ingredient_search => IngredientSearch(),
            AddMealIngredientStage.ingredient_form => IngredientForm(),
            AddMealIngredientStage.portion_add => PortionForm(),
            AddMealIngredientStage.portion_search => PortionSearch(),
            AddMealIngredientStage.amount_form => throw UnimplementedError(),
            AddMealIngredientStage.completed => throw UnimplementedError(),
          },
        ),
        ElevatedButton(
          onPressed: () {
            addingStateNotifier.nextStage();
          },
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _textWithSearchTransition(String text, Icon icon, Function f) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          Align(
            alignment: Alignment.centerRight,
            child: Expanded(
              child: IconButton(
                onPressed: () {
                  f();
                },
                icon: icon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
