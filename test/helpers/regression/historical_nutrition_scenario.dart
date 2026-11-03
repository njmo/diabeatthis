import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart';

/// Real SQLite triggers, with explicit event times instead of wall-clock sleeps.
class HistoricalNutritionScenario {
  final DatabaseImpl db;
  final DateTime eatenAt = DateTime(2026, 9, 1, 12);
  late int ingredientId;
  HistoricalNutritionScenario(this.db);

  Future<void> seedIngredient() async {
    ingredientId = await db
        .into(db.ingredient)
        .insert(
          IngredientCompanion.insert(
            name: 'Recorded ingredient',
            carbsPer100g: 20,
            fiberPer100g: 5,
            fatPer100g: 4,
            proteinPer100g: 6,
            nutritionConfidence: .4,
            carbsLabelMode: const Value('non_eu'),
            createdAt: Value(
              eatenAt.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
            ),
            updatedAt: Value(
              eatenAt.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
            ),
          ),
        );
  }

  Future<int> seedMeal({
    bool snapshots = true,
    bool consumed = true,
    bool zeroConsumed = false,
  }) async {
    final at = eatenAt.millisecondsSinceEpoch;
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Historical meal',
            plannedAt: at,
            status: const Value('summarized'),
            summarizedAt: Value(at + 1200000),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
    await db
        .into(db.mealStatusHistory)
        .insert(
          MealStatusHistoryCompanion.insert(
            mealId: id,
            status: 'eating',
            createdAt: Value(at),
          ),
        );
    await db
        .into(db.mealIngredients)
        .insert(
          MealIngredientsCompanion.insert(
            mealId: id,
            ingredientId: ingredientId,
            amount: const Value(200),
            consumedAmount: Value(zeroConsumed ? 0 : 150),
            quantityConfidence: .8,
            consumedConfidence: const Value(.8),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
    if (snapshots) {
      await db.into(db.mealSnapshot).insert(snapshot(id, consumed: false));
      if (consumed) {
        await db
            .into(db.mealSnapshot)
            .insert(snapshot(id, consumed: true, zero: zeroConsumed));
      }
    }
    return id;
  }

  MealSnapshotCompanion snapshot(
    int id, {
    required bool consumed,
    bool zero = false,
  }) => MealSnapshotCompanion.insert(
    mealId: id,
    snapshotType: consumed ? 'consumed' : 'planned',
    totalGrams: zero
        ? 0
        : consumed
        ? 150
        : 200,
    totalCarbsG: zero
        ? 0
        : consumed
        ? 30
        : 40,
    totalFiberG: zero
        ? 0
        : consumed
        ? 7.5
        : 10,
    totalNetCarbsG: zero
        ? 0
        : consumed
        ? 22.5
        : 30,
    totalFatG: zero
        ? 0
        : consumed
        ? 6
        : 8,
    totalProteinG: zero
        ? 0
        : consumed
        ? 9
        : 12,
    totalCaloriesKcal: zero
        ? 0
        : consumed
        ? 210
        : 280,
    ingredientsCount: const Value(1),
    carbWeightedNutritionConfidence: Value(zero ? null : .4),
    carbWeightedQuantityConfidence: Value(zero ? null : .8),
    carbWeightedEffectiveConfidence: Value(zero ? null : .32),
    createdAt: Value(eatenAt.millisecondsSinceEpoch),
    updatedAt: Value(eatenAt.millisecondsSinceEpoch),
  );

  Future<void> revise({
    required DateTime at,
    required double carbs,
    required double fat,
    required double confidence,
  }) async {
    await (db.update(
      db.ingredient,
    )..where((row) => row.id.equals(ingredientId))).write(
      IngredientCompanion(
        carbsPer100g: Value(carbs),
        fatPer100g: Value(fat),
        nutritionConfidence: Value(confidence),
        updatedAt: Value(at.millisecondsSinceEpoch),
      ),
    );
    // The trigger supplies OLD facts. Control only its clock for this scenario.
    final history =
        await (db.select(db.ingredientStatusHistory)
              ..where((row) => row.ingredientId.equals(ingredientId))
              ..orderBy([(row) => OrderingTerm.desc(row.id)])
              ..limit(1))
            .getSingle();
    await (db.update(
      db.ingredientStatusHistory,
    )..where((row) => row.id.equals(history.id))).write(
      IngredientStatusHistoryCompanion(
        createdAt: Value(at.millisecondsSinceEpoch),
      ),
    );
  }
}
