import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/domain/model/meal.dart' as domain;
import '../../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../models/meal_list_filter.dart';

part 'load_meal_page_by_filter_use_case.g.dart';

@riverpod
Stream<List<domain.Meal>> mealListWindow(
  Ref ref, {
  required MealListFilter filter,
  required int limit,
}) {
  final db = ref.watch(databaseProvider);
  final meals = filter.map(
    recent: (_) => db.mealDao.watchRecentMeals(limit: limit),
    byQuery: (filter) =>
        db.mealDao.watchMealsByName(queryString: filter.query, limit: limit),
    byIngredients: (filter) => db.mealDao.watchMealsByIngredientIds(
      ingredientIds: filter.ingredientIds
          .take(mealIngredientFilterLimit)
          .toList(growable: false),
      limit: limit,
    ),
  );
  return meals.map((items) => items.toDomainList());
}
