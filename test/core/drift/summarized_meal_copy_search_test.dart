import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every copy search filters summarized meals before applying its limit',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final ingredient = await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Rice',
              carbsPer100g: 20,
              fatPer100g: 1,
              fiberPer100g: 1,
              proteinPer100g: 2,
              nutritionConfidence: .8,
            ),
          );
      final summarizedIds = <int>[];
      for (var i = 0; i < 15; i++) {
        final summarized = i < 2;
        final id = await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: 'Dinner $i',
                plannedAt: i,
                updatedAt: Value(i),
                status: Value(
                  summarized
                      ? 'summarized'
                      : i.isEven
                      ? 'planned'
                      : 'eating',
                ),
              ),
            );
        if (summarized) summarizedIds.add(id);
        await db
            .into(db.mealIngredients)
            .insert(
              MealIngredientsCompanion.insert(
                mealId: id,
                ingredientId: ingredient,
                amount: const Value(100),
                quantityConfidence: 1,
              ),
            );
      }
      final results = [
        await db.mealDao.searchRecentMeals(onlySummarized: true),
        await db.mealDao.searchMealsByName('Dinner', onlySummarized: true),
        await db.mealDao.searchMealsByIngredientIds(
          ingredientIds: [ingredient],
          onlySummarized: true,
        ),
        await db.mealDao.searchMealsByNameAndIngredientIds(
          queryString: 'Dinner',
          ingredientIds: [ingredient],
          onlySummarized: true,
        ),
      ];
      for (final rows in results) {
        expect(rows.map((row) => row.id), unorderedEquals(summarizedIds));
        expect(rows.every((row) => row.status == 'summarized'), isTrue);
      }
    },
  );
}
