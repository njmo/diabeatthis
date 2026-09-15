import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_analysis_meal_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingMealRepository extends DayAnalysisMealRepository {
  final int failedId;
  const FailingMealRepository(super.db, this.failedId);

  @override
  Future<DayAnalysisMeal> loadMeal(int id) {
    if (id == failedId) throw StateError('Read failed');
    return super.loadMeal(id);
  }
}

void main() {
  test(
    'analysis preserves consumed macros, actual timing and successful meals',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final start = DateTime(2026, 9, 10);
      Future<int> meal(String name) => db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: name,
              plannedAt: start.millisecondsSinceEpoch,
              status: const Value('eaten'),
            ),
          );
      final id = await meal('Breakfast');
      final failedId = await meal('Unreadable');
      Future<void> stage(String status, int minutes) => db
          .into(db.mealStatusHistory)
          .insert(
            MealStatusHistoryCompanion.insert(
              mealId: id,
              status: status,
              createdAt: Value(
                start.add(Duration(minutes: minutes)).millisecondsSinceEpoch,
              ),
            ),
          );
      await stage('bolused-waiting', 10);
      await stage('eating', 25);
      await stage('eaten', 40);
      for (final type in ['planned', 'consumed']) {
        await db.customStatement(
          '''INSERT INTO meal_snapshot
        (meal_id,snapshot_type,total_grams,total_carbs_g,total_fiber_g,
        total_net_carbs_g,total_fat_g,total_protein_g,total_calories_kcal)
        VALUES (?,?,100,?,0,?,15,10,250)''',
          [id, type, type == 'planned' ? 30 : 20, type == 'planned' ? 30 : 20],
        );
      }
      final ingredientId = await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Bread',
              carbsPer100g: 50,
              fatPer100g: 2,
              fiberPer100g: 1,
              proteinPer100g: 5,
              nutritionConfidence: 1,
            ),
          );
      await db
          .into(db.mealIngredients)
          .insert(
            MealIngredientsCompanion.insert(
              mealId: id,
              ingredientId: ingredientId,
              amount: const Value(50),
              consumedAmount: const Value(40),
              quantityConfidence: 1,
            ),
          );
      final result = await FailingMealRepository(
        db,
        failedId,
      ).loadBetween(start, start.add(const Duration(days: 1)));
      expect(result.failedIds, {failedId});
      final recorded = result.meals.single;
      expect(recorded.id, id);
      expect(recorded.eatenAt, start.add(const Duration(minutes: 25)));
      expect(recorded.eatingEndedAt, start.add(const Duration(minutes: 40)));
      expect(recorded.wait, const Duration(minutes: 15));
      expect(recorded.macros!.netCarbsGrams, 20);
      expect(recorded.macroSource, 'consumed');
      expect(recorded.window, const Duration(hours: 3));
      expect(recorded.ingredients, [(name: 'Bread', grams: 40.0)]);
      final recovered = await DayAnalysisMealRepository(
        db,
      ).loadBetween(start, start.add(const Duration(days: 1)));
      expect(recovered.failedIds, isEmpty);
      expect(recovered.meals, hasLength(2));
      final missing = recovered.meals.singleWhere((m) => m.id == failedId);
      expect(missing.macros, isNull);
      expect(missing.macroSource, 'missing');
    },
  );
}
