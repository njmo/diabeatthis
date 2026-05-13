import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('deleting meal cascades generated meal data', () async {
    final meal = await db
        .into(db.meal)
        .insertReturning(MealCompanion.insert(name: 'Obiad', plannedAt: 1));
    final ingredient = await db
        .into(db.ingredient)
        .insertReturning(
          IngredientCompanion.insert(
            name: 'Ryż',
            carbsPer100g: 28,
            fatPer100g: 0.3,
            fiberPer100g: 0.4,
            proteinPer100g: 2.7,
            nutritionConfidence: 0.8,
          ),
        );

    await db
        .into(db.mealIngredients)
        .insert(
          MealIngredientsCompanion.insert(
            mealId: meal.id,
            ingredientId: ingredient.id,
            amount: const Value(150),
            quantityConfidence: 0.9,
          ),
        );
    await db
        .into(db.mealSnapshot)
        .insert(_snapshot(meal.id, snapshotType: 'planned'));
    await db
        .into(db.mealSnapshot)
        .insert(_snapshot(meal.id, snapshotType: 'consumed'));
    await db
        .into(db.mealAdvisorResult)
        .insert(
          MealAdvisorResultCompanion.insert(
            mealId: Value(meal.id),
            result: 'wait',
            initialWaitTime: 15,
            finalWaitTime: 12,
            waitTimeIgnored: false,
          ),
        );
    await db.mealDao.updateMealStatus(meal.id, 'eating');

    await db.deleteMealById(meal.id);

    expect(await db.mealDao.getMealById(meal.id), isNull);
    expect(await db.select(db.mealIngredients).get(), isEmpty);
    expect(await db.select(db.mealSnapshot).get(), isEmpty);
    expect(await db.select(db.mealAdvisorResult).get(), isEmpty);
    expect(await db.select(db.mealStatusHistory).get(), isEmpty);
    expect(await db.ingredientDao.getIngredientById(ingredient.id), isNotNull);
  });
}

MealSnapshotCompanion _snapshot(int mealId, {required String snapshotType}) {
  return MealSnapshotCompanion.insert(
    mealId: mealId,
    snapshotType: snapshotType,
    totalGrams: 150,
    totalCarbsG: 42,
    totalFiberG: 0.6,
    totalNetCarbsG: 41.4,
    totalFatG: 0.45,
    totalProteinG: 4.05,
    totalCaloriesKcal: 188,
    ingredientsCount: const Value(1),
  );
}
