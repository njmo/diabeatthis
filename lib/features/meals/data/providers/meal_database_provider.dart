import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../drafts/meal_draft.dart';
import '../mapper/meal_draft_mapper.dart';

part 'meal_database_provider.g.dart';

@riverpod
void updateMeal(Ref ref, domain.Meal meal, String status) {
  final db = ref.watch(databaseProvider);
  db.mealDao.updateMealStatus(meal.id, status);
}

@riverpod
void updateMealById(Ref ref, int mealId, String status) {
  final db = ref.watch(databaseProvider);
  db.mealDao.updateMealStatus(mealId, status);
}

@riverpod
Stream<List<domain.Meal>> mealsStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.allMeals().watch().map((e) => e.toDomainList());
}

@riverpod
Future<void> removeMealById(Ref ref, domain.Meal meal) async {
  final db = ref.watch(databaseProvider);
  await db.deleteMealById(meal.id);
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
Future<void> insertMealIngredient(
  Ref ref,
  domain.Ingredient ingredient,
  domain.Meal meal,
  domain.Portion? portion,
  int amount,
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
