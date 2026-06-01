import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../meals/data/providers/meal_draft_provider.dart';
import '../models/ingredient_filter_item.dart';

part 'ingredient_filter_controller.g.dart';

const _ingredientFilterControllerName = 'ingredientFilter';
const _ingredientFilterDraftControllerName = 'ingredientFilterDraft';

final ingredientFilterProvider = ingredientFilterControllerProvider(
  _ingredientFilterControllerName,
);
final ingredientFilterDraftProvider = ingredientFilterControllerProvider(
  _ingredientFilterDraftControllerName,
);

@riverpod
class IngredientFilterController extends _$IngredientFilterController {
  @override
  List<IngredientFilterItem> build(String name) {
    final mealIngredients = ref.read(
      mealDraftProvider.select((draft) => draft.mealIngredients),
    );
    final result = <IngredientFilterItem>[];
    final seenIds = <int>{};

    for (final mealIngredient in mealIngredients) {
      final ingredient = mealIngredient.ingredient.toFilterItem();
      if (ingredient != null && seenIds.add(ingredient.id)) {
        result.add(ingredient);
      }
    }

    return result;
  }

  void overrideItems(List<IngredientFilterItem> ingredients) {
    state = ingredients;
  }

  void addIngredient(IngredientFilterItem ingredient) {
    if (state.any((item) => item.id == ingredient.id)) {
      return;
    }
    state = [...state, ingredient.copyWith(removable: true)];
  }

  void removeIngredient(int ingredientId) {
    final ingredient = state
        .where((item) => item.id == ingredientId)
        .firstOrNull;
    if (ingredient?.removable == false) {
      return;
    }
    state = [
      for (final ingredient in state)
        if (ingredient.id != ingredientId) ingredient,
    ];
  }

  void clearAdditionalIngredients() {
    final remainingIngredients = [
      for (final ingredient in state)
        if (!ingredient.removable) ingredient,
    ];
    state = remainingIngredients;
  }
}
