import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../ingredients/data/models/ingredient_filter_item.dart';
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
    final filter = state.filter.copyWithQuery(normalizedQuery);
    _setFilter(filter);
  }

  void setIngredientFilterItems(List<IngredientFilterItem> ingredients) {
    final ingredientIds = ingredients
        .take(mealIngredientFilterLimit)
        .map((ingredient) => ingredient.id)
        .toList(growable: false);
    final filter = state.filter.copyWithIngredientIds(ingredientIds);
    _setFilter(filter);
  }

  void loadNextPage() {
    state = state.copyWith(visibleLimit: state.visibleLimit + mealListPageSize);
  }

  Future<void> deleteMeal(int mealId) async {
    await ref.read(removeMealByIdProvider(mealId).future);
  }

  void _setFilter(MealListFilter filter) {
    if (state.filter == filter) {
      return;
    }

    state = state.copyWith(filter: filter, visibleLimit: mealListPageSize);
  }
}
