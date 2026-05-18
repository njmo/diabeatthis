import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart';
import '../../data/models/meal_list_filter.dart';
import '../../data/providers/meal_database_provider.dart';
import '../models/meal_list_state.dart';

part 'meal_list_controller.g.dart';

@riverpod
class MealListController extends _$MealListController {
  static const _queryDebounceDuration = Duration(milliseconds: 300);

  Timer? _queryDebounceTimer;

  @override
  MealListState build() {
    ref.onDispose(() {
      _queryDebounceTimer?.cancel();
    });
    return const MealListState.initial();
  }

  void setQuery(String value) {
    _queryDebounceTimer?.cancel();
    final normalizedQuery = value.trim();
    if (normalizedQuery.isEmpty) {
      _setQueryNow(normalizedQuery);
      return;
    }

    _queryDebounceTimer = Timer(_queryDebounceDuration, () {
      _setQueryNow(normalizedQuery);
    });
  }

  void _setQueryNow(String normalizedQuery) {
    final filter = normalizedQuery.isEmpty
        ? const MealListFilter.recent()
        : MealListFilter.byQuery(query: normalizedQuery);
    _setFilter(filter: filter, selectedIngredients: const []);
  }

  void setIngredients(List<Ingredient> ingredients) {
    _queryDebounceTimer?.cancel();
    final limitedIngredients = ingredients
        .take(mealIngredientFilterLimit)
        .toList(growable: false);
    final ingredientIds = limitedIngredients
        .map((ingredient) => ingredient.id)
        .toList(growable: false);
    final filter = ingredientIds.isEmpty
        ? const MealListFilter.recent()
        : MealListFilter.byIngredients(ingredientIds: ingredientIds);
    _setFilter(filter: filter, selectedIngredients: limitedIngredients);
  }

  void removeIngredient(int ingredientId) {
    final ingredients = [
      for (final ingredient in state.selectedIngredients)
        if (ingredient.id != ingredientId) ingredient,
    ];
    setIngredients(ingredients);
  }

  void clearIngredients() {
    setIngredients(const []);
  }

  void loadNextPage() {
    state = state.copyWith(visibleLimit: state.visibleLimit + mealListPageSize);
  }

  Future<void> deleteMeal(int mealId) async {
    await ref.read(removeMealByIdProvider(mealId).future);
  }

  void _setFilter({
    required MealListFilter filter,
    required List<Ingredient> selectedIngredients,
  }) {
    if (state.filter == filter &&
        _sameIngredientSelection(
          state.selectedIngredients,
          selectedIngredients,
        )) {
      return;
    }

    state = state.copyWith(
      filter: filter,
      selectedIngredients: selectedIngredients,
      visibleLimit: mealListPageSize,
    );
  }
}

bool _sameIngredientSelection(List<Ingredient> left, List<Ingredient> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].id != right[index].id) {
      return false;
    }
  }
  return true;
}
