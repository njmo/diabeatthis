import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../ingredients/data/providers/ingredient_filter_controller.dart';
import '../mapper/copied_meal_type_mapper.dart';
import '../model/copied_meal_type.dart';
import '../models/meal_list_filter.dart';

part 'copied_meal_provider.g.dart';

@riverpod
MealListFilter copiedMealFilter(Ref ref, String query) {
  final ingredientIds = ref
      .watch(ingredientFilterProvider)
      .map((ingredient) => ingredient.id)
      .toList(growable: false);
  return MealListFilter.from(query: query, ingredientIds: ingredientIds);
}

@riverpod
Future<List<CopiedMealType>> copiedFromMealByQuery(
  Ref ref,
  String query,
) async {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(copiedMealFilterProvider(query));
  final meals = await filter.map(
    recent: (_) => db.mealDao.searchRecentMeals(),
    byQuery: (filter) => db.mealDao.searchMealsByName(filter.query),
    byIngredients: (filter) => db.mealDao.searchMealsByIngredientIds(
      ingredientIds: filter.ingredientIds,
    ),
    byQueryAndIngredients: (filter) =>
        db.mealDao.searchMealsByNameAndIngredientIds(
          queryString: filter.query,
          ingredientIds: filter.ingredientIds,
        ),
  );
  return meals.map((e) => e.toCopiedMealType()).toList();
}

@riverpod
Future<List<CopiedMealType>> copiedFromMealTemplateByQuery(
  Ref ref,
  String query,
) async {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(copiedMealFilterProvider(query));
  final meals = await filter.map(
    recent: (_) => db.mealTemplateDao.searchRecentMealTemplates(),
    byQuery: (filter) =>
        db.mealTemplateDao.searchMealTemplatesByName(filter.query),
    byIngredients: (filter) =>
        db.mealTemplateDao.searchMealTemplatesByIngredientIds(
          ingredientIds: filter.ingredientIds,
        ),
    byQueryAndIngredients: (filter) =>
        db.mealTemplateDao.searchMealTemplatesByNameAndIngredientIds(
          queryString: filter.query,
          ingredientIds: filter.ingredientIds,
        ),
  );
  return meals.map((e) => e.toCopiedMealType()).toList();
}

@riverpod
Future<int?> copiedMealPreviewTarget(Ref ref, CopiedMealType copiedMeal) async {
  final db = ref.watch(databaseProvider);
  final meal = await db.mealDao.getLatestMealForCopySource(
    baseMealId: copiedMeal.previewBaseMealId,
    mealTemplateId: copiedMeal.previewTemplateId,
  );
  return meal?.id;
}
