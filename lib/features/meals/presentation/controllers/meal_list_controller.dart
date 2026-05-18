import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart';
import '../../data/domain/use_cases/load_meal_page_by_filter_use_case.dart';
import '../../data/models/meal_list_filter.dart';
import '../../data/providers/meal_database_provider.dart';
import '../models/meal_list_state.dart';

part 'meal_list_controller.g.dart';

@riverpod
class MealListController extends _$MealListController {
  static const _queryDebounceDuration = Duration(milliseconds: 300);

  late LoadMealPageByFilterUseCase _loadMealPageByFilter;
  Timer? _queryDebounceTimer;
  int _latestFilterLoadId = 0;

  @override
  Future<MealListState> build() async {
    _loadMealPageByFilter = ref.watch(loadMealPageByFilterUseCaseProvider);
    ref.onDispose(() {
      _queryDebounceTimer?.cancel();
    });
    return _loadFirstPage(
      filter: const MealListFilter.recent(),
      selectedIngredients: const [],
    );
  }

  void setQuery(String value) {
    _queryDebounceTimer?.cancel();
    final normalizedQuery = value.trim();
    if (normalizedQuery.isEmpty) {
      unawaited(_setQueryNow(normalizedQuery));
      return;
    }

    _queryDebounceTimer = Timer(_queryDebounceDuration, () {
      unawaited(_setQueryNow(normalizedQuery));
    });
  }

  Future<void> _setQueryNow(String normalizedQuery) async {
    final filter = normalizedQuery.isEmpty
        ? const MealListFilter.recent()
        : MealListFilter.byQuery(query: normalizedQuery);
    await _setFilter(filter: filter, selectedIngredients: const []);
  }

  Future<void> setIngredients(List<Ingredient> ingredients) async {
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
    await _setFilter(filter: filter, selectedIngredients: limitedIngredients);
  }

  Future<void> removeIngredient(int ingredientId) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final ingredients = [
      for (final ingredient in current.selectedIngredients)
        if (ingredient.id != ingredientId) ingredient,
    ];
    await setIngredients(ingredients);
  }

  Future<void> clearIngredients() async {
    await setIngredients(const []);
  }

  Future<void> retryCurrentFilter() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    await _setFilter(
      filter: current.filter,
      selectedIngredients: current.selectedIngredients,
      force: true,
    );
  }

  Future<void> loadNextPage() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final pageItems = await _loadMealPageByFilter.call(
        filter: current.filter,
        page: current.nextPage,
      );
      final latest = state.value;
      if (latest == null || latest.filter != current.filter) {
        return;
      }
      state = AsyncData(
        latest.copyWith(
          meals: [...latest.meals, ...pageItems],
          nextPage: latest.nextPage + 1,
          hasMore: pageItems.length == mealListPageSize,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (error) {
      final latest = state.value;
      if (latest == null || latest.filter != current.filter) {
        return;
      }
      state = AsyncData(
        latest.copyWith(isLoadingMore: false, loadMoreError: error.toString()),
      );
    }
  }

  Future<void> deleteMeal(int mealId) async {
    await ref.read(removeMealByIdProvider(mealId).future);
    removeMealFromList(mealId);
  }

  void removeMealFromList(int mealId) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        meals: [
          for (final meal in current.meals)
            if (meal.id != mealId) meal,
        ],
      ),
    );
  }

  Future<void> _setFilter({
    required MealListFilter filter,
    required List<Ingredient> selectedIngredients,
    bool force = false,
  }) async {
    final current = state.value;
    if (!force &&
        current?.filter == filter &&
        _sameIngredientSelection(
          current?.selectedIngredients ?? const [],
          selectedIngredients,
        )) {
      return;
    }

    final requestId = _latestFilterLoadId + 1;
    _latestFilterLoadId = requestId;
    if (current == null) {
      state = const AsyncLoading();
    } else {
      state = AsyncData(
        current.copyWith(
          filter: filter,
          selectedIngredients: selectedIngredients,
          meals: const [],
          nextPage: 0,
          hasMore: true,
          isRefreshing: true,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    }

    try {
      final nextState = await _loadFirstPage(
        filter: filter,
        selectedIngredients: selectedIngredients,
      );
      if (requestId != _latestFilterLoadId) {
        return;
      }
      final latest = state.value;
      if (latest != null && latest.filter != filter) {
        return;
      }
      state = AsyncData(nextState);
    } catch (error, stackTrace) {
      if (requestId != _latestFilterLoadId) {
        return;
      }
      final latest = state.value;
      if (latest == null) {
        state = AsyncError(error, stackTrace);
        return;
      }
      state = AsyncData(
        latest.copyWith(
          isRefreshing: false,
          isLoadingMore: false,
          loadMoreError: error.toString(),
        ),
      );
    }
  }

  Future<MealListState> _loadFirstPage({
    required MealListFilter filter,
    required List<Ingredient> selectedIngredients,
  }) async {
    final meals = await _loadMealPageByFilter.call(filter: filter, page: 0);
    return MealListState(
      filter: filter,
      selectedIngredients: selectedIngredients,
      meals: meals,
      nextPage: 1,
      hasMore: meals.length == mealListPageSize,
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
