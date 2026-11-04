import 'package:diabeatthis/common/meal/meal_bolus_coverage.dart';
import 'package:diabeatthis/common/meal/recorded_meal_conversion_unavailable.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late int mealId;
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    mealId = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Legacy dinner',
            plannedAt: DateTime(2026, 9, 21).millisecondsSinceEpoch,
            status: const Value('eaten-bolused'),
          ),
        );
    final ingredientId = await db
        .into(db.ingredient)
        .insert(
          IngredientCompanion.insert(
            name: 'Bread',
            carbsPer100g: 40,
            fatPer100g: 2,
            proteinPer100g: 8,
            fiberPer100g: 3,
            nutritionConfidence: 1,
          ),
        );
    final portionId = await db
        .into(db.portion)
        .insert(PortionCompanion.insert(name: 'Slice', unitHint: 'piece'));
    // Imported entry without historical grams and without a current mapping.
    await db
        .into(db.mealIngredients)
        .insert(
          MealIngredientsCompanion.insert(
            mealId: mealId,
            ingredientId: ingredientId,
            portionId: Value(portionId),
            amount: const Value(2),
            quantityConfidence: 1,
          ),
        );
  });
  tearDown(() => db.close());

  test(
    'saved consumed snapshot is read without recalculating unknown portions',
    () async {
      await db
          .into(db.mealSnapshot)
          .insert(
            MealSnapshotCompanion.insert(
              mealId: mealId,
              snapshotType: 'consumed',
              totalGrams: 90,
              totalCarbsG: 36,
              totalFiberG: 3,
              totalNetCarbsG: 33,
              totalFatG: 2,
              totalProteinG: 7,
              totalCaloriesKcal: 190,
            ),
          );
      final before = await db.select(db.mealIngredients).getSingle();
      expect(before.gramsPerPortionUsed, isNull);
      final coverage = await readMealBolusCoverage(db, mealId);
      expect(coverage.hasRecordedBolus, isTrue);
      expect(coverage.statusBaselineCarbs, 33);
      expect(await db.select(db.mealIngredients).getSingle(), before);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final details = await container
          .read(loadMealDetailsUseCaseProvider)
          .call(mealId);
      expect(details.consumedSnapshot?.totalNetCarbsG, 33);
      expect(details.ingredients.single.recordedWeightAvailable, isFalse);
    },
  );

  test(
    'missing snapshot and conversion remain blocked without changing ingredients',
    () async {
      final before = await db.select(db.mealIngredients).getSingle();
      await expectLater(
        readMealBolusCoverage(db, mealId),
        throwsA(isA<RecordedMealConversionUnavailable>()),
      );
      expect(await db.select(db.mealIngredients).getSingle(), before);
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
    },
  );
}
