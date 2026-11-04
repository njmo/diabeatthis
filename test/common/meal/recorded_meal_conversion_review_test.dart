import 'package:diabeatthis/common/meal/recorded_meal_conversion_repository.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late int mealId;
  late int ingredientId;
  late int portionId;
  late int entryId;
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    mealId = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Old dinner',
            plannedAt: 1000,
            status: const Value('eaten-bolused'),
          ),
        );
    ingredientId = await db
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
    portionId = await db
        .into(db.portion)
        .insert(PortionCompanion.insert(name: 'Slice', unitHint: 'piece'));
    await db
        .into(db.ingredientPortions)
        .insert(
          IngredientPortionsCompanion.insert(
            ingredientId: ingredientId,
            portionId: portionId,
            gramsPerPortion: 45,
          ),
        );
    await db.withRecordedFactsPreserved(() async {
      entryId = await db
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
  });
  tearDown(() => db.close());

  test(
    'current mapping is only a suggestion until explicitly accepted',
    () async {
      final repository = RecordedMealConversionRepository(db);
      final requests = await repository.missingForMeal(mealId);
      expect(requests.single.currentGrams, 45);
      final before = await db.select(db.mealIngredients).getSingle();
      expect(before.gramsPerPortionUsed, isNull);
      await repository.confirm({
        requests.single: requests.single.currentGrams!,
      });
      final after = await db.select(db.mealIngredients).getSingle();
      expect(after.gramsPerPortionUsed, 45);
      expect(after.amount, before.amount);
      expect(after.consumedAmount, before.consumedAmount);
      expect(
        (await db.select(db.ingredientPortions).getSingle()).gramsPerPortion,
        45,
      );
      await db.portionDao.updateIngredientPortionAmount(
        ingredientId: ingredientId,
        portionId: portionId,
        gramsPerPortion: 90,
      );
      expect(
        (await db.select(db.mealIngredients).getSingle()).gramsPerPortionUsed,
        45,
      );
      expect(await repository.missingForMeal(mealId), isEmpty);
    },
  );

  test(
    'custom historical weight does not change global portion mapping',
    () async {
      final repository = RecordedMealConversionRepository(db);
      final request = (await repository.missingForMeal(mealId)).single;
      await repository.confirm({request: 32.5});
      expect(
        (await db.select(db.mealIngredients).getSingle()).gramsPerPortionUsed,
        32.5,
      );
      expect(
        (await db.select(db.ingredientPortions).getSingle()).gramsPerPortion,
        45,
      );
    },
  );

  test(
    'existing recorded factors are excluded and cannot be overwritten',
    () async {
      final repository = RecordedMealConversionRepository(db);
      final request = (await repository.missingForMeal(mealId)).single;
      await repository.confirm({request: 30});
      await expectLater(repository.confirm({request: 60}), throwsStateError);
      expect(
        (await db.select(db.mealIngredients).getSingle()).gramsPerPortionUsed,
        30,
      );
    },
  );

  test('invalid values leave missing conversions untouched', () async {
    final repository = RecordedMealConversionRepository(db);
    final request = (await repository.missingForMeal(mealId)).single;
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
        repository.confirm({request: value}),
        throwsArgumentError,
      );
    }
    expect(
      (await db.select(db.mealIngredients).getSingle()).gramsPerPortionUsed,
      isNull,
    );
  });

  test('one stale entry rolls back the entire reviewed set', () async {
    await db.withRecordedFactsPreserved(() async {
      await db
          .into(db.mealIngredients)
          .insert(
            MealIngredientsCompanion.insert(
              mealId: mealId,
              ingredientId: ingredientId,
              portionId: Value(portionId),
              amount: const Value(1),
              quantityConfidence: 1,
            ),
          );
    });
    final repository = RecordedMealConversionRepository(db);
    final requests = await repository.missingForMeal(mealId);
    await repository.confirm({requests.last: 20});
    await expectLater(
      repository.confirm({for (final request in requests) request: 40}),
      throwsStateError,
    );
    final original = await (db.select(
      db.mealIngredients,
    )..where((row) => row.id.equals(entryId))).getSingle();
    expect(original.gramsPerPortionUsed, isNull);
  });
}
