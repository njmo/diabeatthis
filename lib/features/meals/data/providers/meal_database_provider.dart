import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../drafts/meal_draft.dart';
import '../mapper/meal_draft_drift_mapper.dart';

part 'meal_database_provider.g.dart';

@Riverpod(keepAlive: true)
Future<void> updateMeal(Ref ref, domain.Meal meal, String status) async {
  final db = ref.read(databaseProvider);
  await db.mealDao.updateMealStatus(meal.id, status);
}

@Riverpod(keepAlive: true)
Future<void> updateMealById(Ref ref, int mealId, String status) async {
  final db = ref.read(databaseProvider);
  await db.mealDao.updateMealStatus(mealId, status);
}

@riverpod
Stream<List<domain.Meal>> mealsStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.allMeals().watch().map((e) => e.toDomainList());
}

@riverpod
Future<void> removeMealById(Ref ref, int mealId) async {
  final db = ref.watch(databaseProvider);
  await db.mealDao.deleteMealAndGeneratedData(mealId);
}

@riverpod
Stream<List<domain.Meal>> mealsForTodayStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.mealDao.getAllMealForToday().map((e) => e.toDomainList());
}

@riverpod
Stream<List<domain.Meal>> plannedMealsForTodayStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.mealDao.getAllPlannedMealForToday().map((e) => e.toDomainList());
}

@riverpod
Stream<List<domain.Meal>> allMealsStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.mealDao.getAllMeals().map((e) => e.toDomainList());
}

@riverpod
Future<List<domain.Meal>> mealListPage(Ref ref, int page) async {
  final db = ref.watch(databaseProvider);
  final meals = await db.mealDao.getAllMeals(page: page).first;
  return meals.toDomainList();
}

@riverpod
Future<void> insertMealIngredient(
  Ref ref,
  domain.Ingredient ingredient,
  domain.Meal meal,
  domain.Portion? portion,
  double amount,
  double nutritionConfidence,
) async {
  final db = ref.watch(databaseProvider);
  final ingredientId = ingredient.map(
    existing: (e) => e.id,
    draft: (_) => throw Exception('Cannot get id for draft'),
  );
  await db.insertMealIngredient(
    meal.id,
    ingredientId,
    portion?.id,
    amount,
    null,
    nutritionConfidence,
    null,
  );
}

@riverpod
Future<void> insertExtraMealIngredient(
  Ref ref,
  domain.Ingredient ingredient,
  int mealId,
  domain.Portion? portion,
  double consumedAmount,
  double consumedQuantityConfidence,
) async {
  final db = ref.watch(databaseProvider);
  final ingredientId = ingredient.map(
    existing: (e) => e.id,
    draft: (_) => throw Exception('Cannot get id for draft'),
  );
  await db.insertExtraMealIngredient(
    mealId,
    ingredientId,
    portion?.id,
    0,
    null,
    consumedAmount,
    consumedQuantityConfidence,
    consumedQuantityConfidence,
    null,
  );
}

@riverpod
Future<domain.Meal?> getMealById(Ref ref, int id) async {
  final db = ref.read(databaseProvider);
  final meal = await db.mealDao.getMealById(id);
  return meal?.toDomain();
}

@riverpod
Future<domain.Meal?> getNearestMeal(Ref ref) async {
  final db = ref.read(databaseProvider);
  final meal = await db.mealDao.getNearestMeal();
  return meal?.toDomain();
}

@riverpod
Future<domain.Meal> insertMeal(Ref ref, MealDraft meal) async {
  final db = ref.watch(databaseProvider);
  final value = await db
      .into(db.meal)
      .insertReturningOrNull(meal.toCompanion());
  if (value != null) {
    return value.toDomain();
  } else {
    throw Exception('Could not insert meal');
  }
}
