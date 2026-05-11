import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/apply_meal_add_on_multiplier_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await _seedMeal(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('applies simple add-on multiplier to planned ingredients', () async {
    final result = await container
        .read(applyMealAddOnMultiplierUseCaseProvider)
        .call(mealId: 1, currentMealStatus: 'eating', multiplier: 1.5);

    final meal = await db.mealDao.getMealById(1);
    final ingredients = await db.mealIngredientsDao.getMealIngredientsForMeal(
      1,
    );

    expect(meal?.status, 'eating-extra');
    expect(ingredients.single.consumedAmount, 150);
    expect(ingredients.single.consumedConfidence, 0.8);
    expect(result.addedNetCarbs, closeTo(7.5, 0.01));
    expect(result.totalNetCarbs, closeTo(22.5, 0.01));
  });
}

Future<void> _seedMeal(DatabaseImpl db) async {
  await db.customInsert('''
    INSERT INTO ingredient (
      id,
      name,
      carbs_per_100g,
      fat_per_100g,
      fiber_per_100g,
      protein_per_100g,
      nutrition_confidence
    ) VALUES (1, 'Ryż', 20, 0, 5, 2, 1)
  ''');

  await db.customInsert('''
    INSERT INTO meal (
      id,
      name,
      planned_at,
      status
    ) VALUES (1, 'Obiad', 1774270800000, 'eating')
  ''');

  await db.customInsert('''
    INSERT INTO meal_ingredients (
      id,
      meal_id,
      ingredient_id,
      portion_id,
      amount,
      quantity_confidence
    ) VALUES (1, 1, 1, NULL, 100, 0.8)
  ''');
}
