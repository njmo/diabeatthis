import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../ingredients/data/models/ingredient_filter_limits.dart';

part 'meal_list_filter.freezed.dart';

const mealListPageSize = 10;
const mealIngredientFilterLimit = ingredientFilterSelectionLimit;

@Freezed(unionKey: 'kind')
class MealListFilter with _$MealListFilter {
  const factory MealListFilter.recent() = _MealListFilterRecent;

  const factory MealListFilter.byQuery({required String query}) =
      _MealListFilterByQuery;

  const factory MealListFilter.byIngredients({
    required List<int> ingredientIds,
  }) = _MealListFilterByIngredients;
}
