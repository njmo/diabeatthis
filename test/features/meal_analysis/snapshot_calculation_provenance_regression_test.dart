import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/mappers/meal_snapshot_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/historical_nutrition_scenario.dart';

void main() {
  for (final knownCalculation in [true, false]) {
    test(
      'snapshot calculation provenance survives later metadata changes; known=$knownCalculation',
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
        final initial =
            await (db.select(db.mealSnapshot)..where(
                  (s) =>
                      s.mealId.equals(mealId) &
                      s.snapshotType.equals('consumed'),
                ))
                .getSingle();
        if (knownCalculation) {
          await withClock(
            Clock.fixed(scenario.eatenAt),
            () => container
                .read(mealSnapshotControllerProvider)
                .saveSnapshot(initial.toDomain()),
          );
        }
        await scenario.revise(
          at: scenario.eatenAt.add(const Duration(hours: 1)),
          carbs: 25,
          fat: 12,
          confidence: .7,
        );
        final metadataAt = scenario.eatenAt
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch;
        await (db.update(
          db.mealSnapshot,
        )..where((s) => s.id.equals(initial.id))).write(
          MealSnapshotCompanion(
            isSynced: const Value(true),
            updatedAt: Value(metadataAt),
          ),
        );
        final stored = await (db.select(
          db.mealSnapshot,
        )..where((s) => s.id.equals(initial.id))).getSingle();
        expect(
          stored.calculatedAt,
          knownCalculation ? scenario.eatenAt.millisecondsSinceEpoch : null,
        );
        expect(stored.totalNetCarbsG, 22.5);
        final details = await container.read(loadMealDetailsUseCaseProvider)(
          mealId,
        );
        final ingredient = details.ingredients.single;
        expect(ingredient.currentNutrition.carbsPer100g, 25);
        expect(
          ingredient.consumedHistoricalNutritionUnavailable,
          !knownCalculation,
        );
        if (knownCalculation) {
          expect(ingredient.consumedNutrition.carbsPer100g, 20);
          expect(ingredient.consumedNutrition.nutritionConfidence, .4);
        }
      },
    );
  }
}
