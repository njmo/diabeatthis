import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_analysis_meal_repository.dart';
import 'package:diabeatthis/features/meals/data/mappers/ingredient_nutrition_mapper.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_details_data_mapper.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_ingredient_amounts_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late MealData meal;
  late IngredientData ingredient;
  late int portionId;
  final recordedAt = DateTime.utc(2026, 9, 10, 12);
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    meal = await db
        .into(db.meal)
        .insertReturning(
          MealCompanion.insert(
            name: 'Meal',
            plannedAt: recordedAt.millisecondsSinceEpoch,
            createdAt: Value(recordedAt.millisecondsSinceEpoch),
            status: const Value('eaten'),
          ),
        );
    ingredient = await db
        .into(db.ingredient)
        .insertReturning(
          IngredientCompanion.insert(
            name: 'Ingredient',
            carbsPer100g: 30,
            fatPer100g: 0,
            fiberPer100g: 1,
            proteinPer100g: 1,
            nutritionConfidence: 1,
            updatedAt: Value(
              recordedAt.add(const Duration(days: 1)).millisecondsSinceEpoch,
            ),
          ),
        );
    portionId = await db
        .into(db.portion)
        .insert(PortionCompanion.insert(name: 'Piece', unitHint: 'piece'));
    await db
        .into(db.ingredientPortions)
        .insert(
          IngredientPortionsCompanion.insert(
            ingredientId: ingredient.id,
            portionId: portionId,
            gramsPerPortion: 40,
          ),
        );
  });
  tearDown(() => db.close());

  Future<MealIngredient> entry({
    int? portion,
    String type = 'planned',
    double? consumed,
  }) => db
      .into(db.mealIngredients)
      .insertReturning(
        MealIngredientsCompanion.insert(
          mealId: meal.id,
          ingredientId: ingredient.id,
          portionId: Value(portion),
          amount: const Value(2),
          consumedAmount: Value(consumed),
          entryType: Value(type),
          quantityConfidence: 1,
          createdAt: Value(recordedAt.millisecondsSinceEpoch),
        ),
      );

  for (final scenario in [
    (
      name: 'grams',
      portion: false,
      reference: false,
      type: 'planned',
      consumed: null,
      plannedG: 2.0,
      consumedG: 2.0,
    ),
    (
      name: 'portion',
      portion: true,
      reference: false,
      type: 'planned',
      consumed: 1.5,
      plannedG: 80.0,
      consumedG: 60.0,
    ),
    (
      name: 'reference',
      portion: true,
      reference: true,
      type: 'planned',
      consumed: 0.5,
      plannedG: 200.0,
      consumedG: 50.0,
    ),
    (
      name: 'unconfirmed extra',
      portion: true,
      reference: false,
      type: 'extra',
      consumed: null,
      plannedG: 0.0,
      consumedG: 0.0,
    ),
    (
      name: 'consumed extra',
      portion: true,
      reference: false,
      type: 'extra',
      consumed: 0.5,
      plannedG: 0.0,
      consumedG: 20.0,
    ),
    (
      name: 'zero consumption',
      portion: true,
      reference: false,
      type: 'planned',
      consumed: 0.0,
      plannedG: 80.0,
      consumedG: 0.0,
    ),
  ]) {
    test(
      'stored amounts preserve ${scenario.name} in details and shared facts',
      () async {
        if (scenario.reference) {
          await (db.update(db.ingredient)
                ..where((t) => t.id.equals(ingredient.id)))
              .write(const IngredientCompanion(isReference: Value(1)));
        }
        final row = await entry(
          portion: scenario.portion ? portionId : null,
          type: scenario.type,
          consumed: scenario.consumed,
        );
        final amounts = await MealIngredientAmountsRepository(db).load(row);
        final details = await MealDetailsDataMapper(db: db).mapIngredient(
          meal: meal,
          mealIngredient: row,
          plannedSnapshot: null,
          consumedSnapshot: null,
        );
        expect(amounts.plannedGrams, scenario.plannedG);
        expect(amounts.consumedGrams, scenario.consumedG);
        expect(details.plannedTotalGrams, scenario.plannedG);
        expect(details.consumedTotalGrams, scenario.consumedG);
      },
    );
  }

  test(
    'missing portion conversion preserves legacy one-gram fallback',
    () async {
      await db.delete(db.ingredientPortions).go();
      final amounts = await MealIngredientAmountsRepository(
        db,
      ).load(await entry(portion: portionId));
      expect(amounts.gramsPerPortion, 1);
      expect(amounts.consumedGrams, 2);
    },
  );

  test(
    'legacy meal observation uses nutrition at consumption, not current nutrition',
    () async {
      final row = await entry(portion: portionId);
      for (final version in [
        (at: recordedAt.subtract(const Duration(hours: 1)), fat: 20.0),
        (at: recordedAt.add(const Duration(hours: 1)), fat: 0.0),
      ]) {
        await db
            .into(db.ingredientStatusHistory)
            .insert(
              IngredientStatusHistoryCompanion.insert(
                ingredientId: ingredient.id,
                carbsPer100g: 30,
                fatPer100g: version.fat,
                fiberPer100g: 1,
                proteinPer100g: 1,
                nutritionConfidence: 1,
                createdAt: Value(version.at.millisecondsSinceEpoch),
              ),
            );
      }
      final details = await MealDetailsDataMapper(db: db).mapIngredient(
        meal: meal,
        mealIngredient: row,
        plannedSnapshot: null,
        consumedSnapshot: null,
      );
      expect(details.consumedNutrition.fatPer100g, 20);
      expect(details.consumedWbtKcalContribution, closeTo(147.2, 0.001));
      final analysis = await DayAnalysisMealRepository(db).loadMeal(meal.id);
      expect(analysis.window, const Duration(hours: 3));
      expect(analysis.macroSource, 'missing');
      expect(analysis.ingredients, [(name: 'Ingredient', grams: 80.0)]);
      final history = await db.ingredientDao.getIngredientStatusHistory(
        ingredient.id,
      );
      final beforeHistory = const IngredientNutritionMapper().at(
        ingredient: ingredient,
        history: history,
        reference: recordedAt.subtract(const Duration(days: 1)),
      );
      expect(beforeHistory.historicalUnavailable, isTrue);
      expect(beforeHistory.nutrition.fatPer100g, 0);
    },
  );
}
