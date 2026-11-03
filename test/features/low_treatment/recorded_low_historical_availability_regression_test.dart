import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/recorded_low_treatment_repository.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/recorded_low_treatments_dml.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [
    (
      name: 'unknown portion without aggregate',
      unknownWeight: true,
      snapshot: false,
      explicit: null,
      historical: null,
      delivery: null,
    ),
    (
      name: 'saved aggregate with unknown portion',
      unknownWeight: true,
      snapshot: true,
      explicit: null,
      historical: 7.6,
      delivery: 8.0,
    ),
    (
      name: 'explicit amount overrides saved aggregate',
      unknownWeight: true,
      snapshot: true,
      explicit: 12,
      historical: 12.0,
      delivery: 12.0,
    ),
    (
      name: 'known grams with unknown historical nutrition',
      unknownWeight: false,
      snapshot: false,
      explicit: null,
      historical: null,
      delivery: 7.0,
    ),
  ]) {
    test(
      'recorded low treatment preserves availability: ${scenario.name}',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final food = await db
            .into(db.ingredient)
            .insert(
              IngredientCompanion.insert(
                name: 'Glucose',
                carbsPer100g: 100,
                fiberPer100g: 0,
                fatPer100g: 0,
                proteinPer100g: 0,
                nutritionConfidence: 1,
                createdAt: const Value(2000),
              ),
            );
        final portion = await db
            .into(db.portion)
            .insert(PortionCompanion.insert(name: 'Spoon', unitHint: 'spoon'));
        final meal = await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: 'Historical low treatment',
                plannedAt: 1000,
                purpose: const Value('lowTreatment'),
                status: const Value('confirmed'),
                createdAt: const Value(1000),
              ),
            );
        await db
            .into(db.mealIngredients)
            .insert(
              MealIngredientsCompanion.insert(
                mealId: meal,
                ingredientId: food,
                portionId: Value(scenario.unknownWeight ? portion : null),
                amount: Value(scenario.unknownWeight ? 2 : 7.35),
                consumedAmount: Value(scenario.unknownWeight ? 2 : 7.35),
                quantityConfidence: 1,
                createdAt: const Value(1000),
              ),
            );
        if (scenario.snapshot) {
          await db
              .into(db.mealSnapshot)
              .insert(
                MealSnapshotCompanion.insert(
                  mealId: meal,
                  snapshotType: 'consumed',
                  totalGrams: 7.6,
                  totalCarbsG: 7.6,
                  totalFiberG: 0,
                  totalNetCarbsG: 7.6,
                  totalFatG: 0,
                  totalProteinG: 0,
                  totalCaloriesKcal: 30.4,
                  createdAt: const Value(1000),
                  updatedAt: const Value(1000),
                ),
              );
        }
        if (scenario.explicit != null) {
          await db
              .into(db.lowTreatmentContext)
              .insert(
                LowTreatmentContextCompanion.insert(
                  mealId: Value(meal),
                  source: 'manual',
                  recordedCarbs: Value(scenario.explicit),
                ),
              );
        }
        final recorded = (await RecordedLowTreatmentRepository(
          db,
        ).fetchByMealId(meal))!;
        expect(recorded.historicalCarbs, scenario.historical);
        expect(recorded.netCarbsGrams, scenario.delivery);
        expect(
          recorded.historicalNutritionUnavailable,
          scenario.historical == null,
        );
        expect(recorded.ingredientsAvailable, !scenario.unknownWeight);
        expect(recorded.ingredients, hasLength(scenario.unknownWeight ? 0 : 1));
        final dml = recordedLowTreatmentsDml([recorded])!.single;
        expect(dml['net_carbs_g'], scenario.historical);
        if (scenario.unknownWeight) {
          expect(dml['ingredient_amounts_available'], false);
        }
        if (scenario.historical == null) {
          expect(dml['nutrition_available'], false);
        }
      },
    );
  }
}
