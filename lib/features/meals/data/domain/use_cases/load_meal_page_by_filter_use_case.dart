import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/domain/model/meal.dart' as domain;
import '../../../../../core/drift/database_impl.dart' show DatabaseImpl;
import '../../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../models/meal_list_filter.dart';

part 'load_meal_page_by_filter_use_case.g.dart';

@riverpod
LoadMealPageByFilterUseCase loadMealPageByFilterUseCase(Ref ref) {
  final db = ref.watch(databaseProvider);
  return LoadMealPageByFilterUseCase(db: db);
}

class LoadMealPageByFilterUseCase {
  final DatabaseImpl db;

  const LoadMealPageByFilterUseCase({required this.db});

  Future<List<domain.Meal>> call({
    required MealListFilter filter,
    required int page,
  }) async {
    final meals = await filter.map(
      recent: (_) =>
          db.mealDao.getRecentMealsPage(page: page, pageSize: mealListPageSize),
      byQuery: (filter) => db.mealDao.searchMealsPageByName(
        queryString: filter.query,
        page: page,
        pageSize: mealListPageSize,
      ),
      byIngredients: (filter) => db.mealDao.getMealsPageByIngredientIds(
        ingredientIds: filter.ingredientIds
            .take(mealIngredientFilterLimit)
            .toList(growable: false),
        page: page,
        pageSize: mealListPageSize,
      ),
    );
    return meals.toDomainList();
  }
}
