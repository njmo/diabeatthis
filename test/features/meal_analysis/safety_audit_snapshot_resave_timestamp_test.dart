import 'package:diabeatthis/core/domain/model/meal_snapshot.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/historical_nutrition_scenario.dart';

void main() {
  test(
    'a re-saved consumed snapshot resolves ingredient nutrition from its latest calculation time',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      final scenario = HistoricalNutritionScenario(db);
      await scenario.seedIngredient();
      final mealId = await scenario.seedMeal();
      final before =
          await (db.select(db.mealSnapshot)..where(
                (row) =>
                    row.mealId.equals(mealId) &
                    row.snapshotType.equals('consumed'),
              ))
              .getSingle();

      await scenario.revise(
        at: scenario.eatenAt.add(const Duration(hours: 1)),
        carbs: 25,
        fat: 12,
        confidence: .7,
      );

      await container
          .read(mealSnapshotControllerProvider)
          .saveSnapshot(
            MealSnapshot(
              mealId: mealId,
              snapshotType: MealSnapshotType.consumed,
              totalGrams: 150,
              totalCarbsG: 37.5,
              totalFiberG: 7.5,
              totalNetCarbsG: 30,
              totalFatG: 18,
              totalProteinG: 9,
              totalCaloriesKcal: 348,
              ingredientsCount: 1,
              avgQuantityConfidence: .8,
              minQuantityConfidence: .8,
              carbWeightedQuantityConfidence: .8,
              wbtWeightedQuantityConfidence: .8,
              carbWeightedNutritionConfidence: .7,
              wbtWeightedNutritionConfidence: .7,
              carbWeightedEffectiveConfidence: .56,
              wbtWeightedEffectiveConfidence: .56,
            ),
          );

      final after =
          await (db.select(db.mealSnapshot)..where(
                (row) =>
                    row.mealId.equals(mealId) &
                    row.snapshotType.equals('consumed'),
              ))
              .getSingle();
      expect(after.createdAt, before.createdAt);
      expect(after.updatedAt, greaterThan(before.updatedAt));
      expect(after.totalNetCarbsG, 30);

      final details = await container.read(loadMealDetailsUseCaseProvider)(
        mealId,
      );
      // The re-saved snapshot's net carbs (30g) reflect 25g carbs/100g,
      // but the constituent resolver still returns the 20g value from its
      // retained createdAt reference (the original 22.5g calculation).
      expect(details.ingredients.single.consumedNutrition.carbsPer100g, 25);
      expect(
        details.ingredients.single.consumedNutrition.nutritionConfidence,
        .7,
      );
    },
  );
}
