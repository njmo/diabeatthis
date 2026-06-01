import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../ingredients/data/models/ingredient_filter_limits.dart';

part 'meal_list_filter.freezed.dart';

const mealListPageSize = 10;
const mealIngredientFilterLimit = ingredientFilterSelectionLimit;

@freezed
abstract class MealListFilter with _$MealListFilter {
  const factory MealListFilter.recent() = _MealListFilterRecent;

  const factory MealListFilter.byQuery({required String query}) =
      _MealListFilterByQuery;

  const factory MealListFilter.byIngredients({
    required List<int> ingredientIds,
  }) = _MealListFilterByIngredients;

  const factory MealListFilter.byQueryAndIngredients({
    required String query,
    required List<int> ingredientIds,
  }) = _MealListFilterByQueryAndIngredients;

  const MealListFilter._();

  factory MealListFilter.from({
    required String query,
    required List<int> ingredientIds,
  }) {
    final normalizedQuery = query.trim();
    final distinctIngredientIds = ingredientIds.toSet().toList(growable: false);
    if (normalizedQuery.isEmpty && distinctIngredientIds.isEmpty) {
      return const MealListFilter.recent();
    }
    if (normalizedQuery.isEmpty) {
      return MealListFilter.byIngredients(ingredientIds: distinctIngredientIds);
    }
    if (distinctIngredientIds.isEmpty) {
      return MealListFilter.byQuery(query: normalizedQuery);
    }
    return MealListFilter.byQueryAndIngredients(
      query: normalizedQuery,
      ingredientIds: distinctIngredientIds,
    );
  }

  String get query => maybeWhen(
    byQuery: (query) => query,
    byQueryAndIngredients: (query, _) => query,
    orElse: () => '',
  );

  List<int> get ingredientIds => maybeWhen(
    byIngredients: (ingredientIds) => ingredientIds,
    byQueryAndIngredients: (_, ingredientIds) => ingredientIds,
    orElse: () => const [],
  );

  bool get isEmpty => this is _MealListFilterRecent;

  MealListFilter copyWithQuery(String query) {
    return MealListFilter.from(query: query, ingredientIds: ingredientIds);
  }

  MealListFilter copyWithIngredientIds(List<int> ingredientIds) {
    return MealListFilter.from(query: query, ingredientIds: ingredientIds);
  }
}
