import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_ai_facts_mapper.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'historical meal retains 60g for two slices after the portion changes from 30g to 40g',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final at = DateTime(2026, 9, 1, 12).millisecondsSinceEpoch;
      final ingredient = await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Bread',
              carbsPer100g: 50,
              fiberPer100g: 0,
              fatPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 1,
              carbsLabelMode: const Value('eu'),
              createdAt: Value(at - 86400000),
              updatedAt: Value(at - 86400000),
            ),
          );
      final portion = await db
          .into(db.portion)
          .insert(PortionCompanion.insert(name: 'Slice', unitHint: 'piece'));
      await db
          .into(db.ingredientPortions)
          .insert(
            IngredientPortionsCompanion.insert(
              ingredientId: ingredient,
              portionId: portion,
              gramsPerPortion: 30,
            ),
          );
      final meal = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Two slices',
              plannedAt: at,
              status: const Value('summarized'),
              summarizedAt: Value(at + 1200000),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      await db
          .into(db.mealIngredients)
          .insert(
            MealIngredientsCompanion.insert(
              mealId: meal,
              ingredientId: ingredient,
              portionId: Value(portion),
              amount: const Value(2),
              consumedAmount: const Value(2),
              quantityConfidence: 1,
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      await db
          .into(db.mealSnapshot)
          .insert(
            MealSnapshotCompanion.insert(
              mealId: meal,
              snapshotType: 'consumed',
              totalGrams: 60,
              totalCarbsG: 30,
              totalFiberG: 0,
              totalNetCarbsG: 30,
              totalFatG: 0,
              totalProteinG: 0,
              totalCaloriesKcal: 120,
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      final load = container.read(loadMealDetailsUseCaseProvider);
      final before = const MealAiFactsMapper().map(await load(meal));
      expect(before.macros!.netCarbsGrams, 30);
      expect(before.ingredients.single.grams, 60);
      await db.portionDao.updateIngredientPortionAmount(
        ingredientId: ingredient,
        portionId: portion,
        gramsPerPortion: 40,
      );
      final after = const MealAiFactsMapper().map(await load(meal));
      expect(after.macros!.netCarbsGrams, 30);
      expect(after.macros!.totalGrams, 60);
      expect(after.ingredients.single.grams, 60);
    },
  );
}
