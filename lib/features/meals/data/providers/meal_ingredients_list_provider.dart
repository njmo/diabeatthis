import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../drafts/meal_draft.dart';
import 'meal_provider.dart';

part 'meal_ingredients_list_provider.g.dart';

@riverpod
List<MealIngredientsDraft> mealDraftIngredients(Ref ref) {
  return ref.watch(
    mealDraftProvider.select((h) => h.mealIngredients),
  );
}

enum AddMealIngredientStage {
  ingredient_search,
  ingredient_form,
  portion_add,
  portion_search,
  amount_form,
  completed,
}

@riverpod
class AddMealIngredientStageNotifier extends _$AddMealIngredientStageNotifier {
  @override
  AddMealIngredientStage build() {
    return AddMealIngredientStage.ingredient_search;
  }
  void setStage(AddMealIngredientStage stage) => state = stage;
  void nextStage() {
    switch (state) {
      case AddMealIngredientStage.ingredient_search:
      case AddMealIngredientStage.ingredient_form:
        state = AddMealIngredientStage.portion_add;
        break;
      case AddMealIngredientStage.portion_add:
      case AddMealIngredientStage.portion_search:
        state = AddMealIngredientStage.amount_form;
        break;
      case AddMealIngredientStage.amount_form:
        state = AddMealIngredientStage.completed;
        break;

      case AddMealIngredientStage.completed:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
  void toOppositeStage()
  {
    switch(state)
    {
      case AddMealIngredientStage.ingredient_search:
        state = AddMealIngredientStage.ingredient_form;
        break;
      case AddMealIngredientStage.portion_search:
        state = AddMealIngredientStage.portion_add;
        break;
      case AddMealIngredientStage.ingredient_form:
        state = AddMealIngredientStage.ingredient_search;
        break;
      case AddMealIngredientStage.portion_add:
        state = AddMealIngredientStage.portion_search;
        break;
      case AddMealIngredientStage.amount_form:
      case AddMealIngredientStage.completed:
        throw UnimplementedError();
    }
  }

}

