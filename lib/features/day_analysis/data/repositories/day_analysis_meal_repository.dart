import 'package:drift/drift.dart';

import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../core/drift/database_impl.dart';
import '../../../../core/logger/logger.dart';
import '../../../meal_analysis/domain/models/meal_observation_window.dart';
import '../../../meals/data/mappers/ingredient_nutrition_mapper.dart';
import '../../../meals/data/repositories/meal_ingredient_amounts_repository.dart';
import '../../../meals/domain/models/recorded_meal_timing.dart';
import '../../domain/models/day_analysis_meal.dart';
import '../../domain/models/day_analysis_meal_batch.dart';
import 'day_local_history_repository.dart';

/// Reads only recorded meal facts; never loads advisor results or copy history.
class DayAnalysisMealRepository with Logging {
  final DatabaseImpl db;
  const DayAnalysisMealRepository(this.db);

  Future<DayAnalysisMealBatch> loadBetween(DateTime start, DateTime end) async {
    final rows = await DayLocalHistoryRepository(
      db,
    ).loadRecordedMeals(start, end);
    final meals = <DayAnalysisMeal>[];
    final failed = <int>{};
    for (final row in rows) {
      try {
        meals.add(await loadMeal(row.id));
      } catch (error) {
        failed.add(row.id);
        logW('Day analysis meal read failed: ${error.runtimeType}');
      }
    }
    return DayAnalysisMealBatch(meals: meals, failedIds: failed);
  }

  Future<DayAnalysisMeal> loadMeal(int id) => db.transaction(() async {
    final meal = await db.mealDao.getMealById(id);
    if (meal == null) throw StateError('Recorded meal missing');
    final amountsRepository = MealIngredientAmountsRepository(db);
    const nutritionMapper = IngredientNutritionMapper();
    final snapshots = await (db.select(
      db.mealSnapshot,
    )..where((t) => t.mealId.equals(id))).get();
    final planned = snapshots
        .where((s) => s.snapshotType == 'planned')
        .firstOrNull;
    final consumed = snapshots
        .where((s) => s.snapshotType == 'consumed')
        .firstOrNull;
    final entries = await db.mealIngredientsDao.getMealIngredientsForMeal(id);
    final snapshot = consumed ?? planned;
    final ingredients = <({String name, double grams})>[];
    var fallbackWbtKcal = 0.0;
    for (final entry in entries) {
      final amounts = await amountsRepository.load(entry);
      ingredients.add((
        name: amounts.ingredient.name,
        grams: consumed == null ? amounts.plannedGrams : amounts.consumedGrams,
      ));
      // Legacy records without snapshots retain the same historical nutrition fallback.
      if (snapshot == null) {
        final history = await db.ingredientDao.getIngredientStatusHistory(
          amounts.ingredient.id,
        );
        final nutrition = nutritionMapper
            .at(
              ingredient: amounts.ingredient,
              history: history,
              reference: DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
            )
            .nutrition;
        fallbackWbtKcal +=
            amounts.consumedGrams * nutrition.wbtKcalPer100g / 100;
      }
    }
    final stages =
        await (db.select(db.mealStatusHistory)
              ..where((t) => t.mealId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    final recordedStages = [
      for (final stage in stages)
        (
          status: stage.status,
          at: DateTime.fromMillisecondsSinceEpoch(stage.createdAt),
        ),
    ];
    final timing = RecordedMealTiming(recordedStages);
    return DayAnalysisMeal(
      id: meal.id,
      name: meal.name,
      eatenAt:
          timing.recordedEatingStartedAt ??
          DateTime.fromMillisecondsSinceEpoch(
            meal.summarizedAt ?? meal.plannedAt,
          ),
      eatingEndedAt: timing.recordedEatingEndedAt,
      wait: timing.recordedWait,
      window: MealObservationWindow.forWbtKcal(
        snapshot == null
            ? fallbackWbtKcal
            : snapshot.totalProteinG * 4 + snapshot.totalFatG * 9,
      ),
      macroSource: consumed != null
          ? 'consumed'
          : planned != null
          ? 'planned'
          : 'missing',
      macros: snapshot == null
          ? null
          : MealMacroSummary(
              carbsGrams: snapshot.totalCarbsG,
              netCarbsGrams: snapshot.totalNetCarbsG,
              proteinGrams: snapshot.totalProteinG,
              fatGrams: snapshot.totalFatG,
              fiberGrams: snapshot.totalFiberG,
              totalGrams: snapshot.totalGrams,
            ),
      ingredients: ingredients,
      stages: recordedStages,
    );
  });
}
