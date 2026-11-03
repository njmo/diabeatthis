import 'package:drift/drift.dart';

import '../../../../common/meal/low_treatment_delivery_carbs.dart';
import '../../../../common/meal/meal_snapshot_history_reader.dart';
import '../../../../core/drift/database_impl.dart';
import '../../../meals/data/mappers/meal_details_data_mapper.dart';
import '../../domain/models/recorded_low_treatment.dart';

/// Local consumption annotations are not supplied by Nightscout history.
class RecordedLowTreatmentRepository {
  final DatabaseImpl db;
  const RecordedLowTreatmentRepository(this.db);

  Future<RecordedLowTreatment?> fetchByMealId(int mealId) =>
      db.transaction(() async {
        final meal = await db.mealDao.getMealById(mealId);
        if (meal == null ||
            meal.purpose != 'lowTreatment' ||
            meal.status != 'confirmed') {
          return null;
        }
        return _mapMeal(meal);
      });

  Future<List<RecordedLowTreatment>> fetchBetween(
    DateTime start,
    DateTime end,
  ) => db.transaction(() async {
    final query = db.select(db.meal)
      ..where(
        (t) =>
            t.purpose.equals('lowTreatment') &
            t.status.equals('confirmed') &
            t.plannedAt.isBetweenValues(
              start.millisecondsSinceEpoch,
              end.millisecondsSinceEpoch,
            ),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.plannedAt)]);
    final meals = await query.get();
    final entries = <RecordedLowTreatment>[];
    for (final meal in meals) {
      entries.add(await _mapMeal(meal));
    }
    return entries;
  });

  Future<RecordedLowTreatment> _mapMeal(MealData meal) async {
    final context = await db.lowTreatmentContextDao.getContextForMeal(meal.id);
    final ingredients = await db.mealIngredientsDao.getMealIngredientsForMeal(
      meal.id,
    );
    final snapshotHistory = await MealSnapshotHistoryReader(db).read(meal.id);
    final snapshots = snapshotHistory.snapshots;
    final plannedSnapshot = snapshots
        .where((s) => s.snapshotType == 'planned')
        .firstOrNull;
    final consumedSnapshot = snapshots
        .where((s) => s.snapshotType == 'consumed')
        .firstOrNull;
    final mapper = MealDetailsDataMapper(db: db);
    final consumedIngredients = <({String name, double grams})>[];
    var carbs = 0.0;
    var nutritionAvailable = ingredients.isNotEmpty;
    var ingredientsAvailable = true;
    var deliveryAvailable = ingredients.isNotEmpty;
    for (final ingredient in ingredients) {
      final mapped = await mapper.mapIngredient(
        meal: meal,
        mealIngredient: ingredient,
        plannedSnapshot: plannedSnapshot,
        consumedSnapshot: consumedSnapshot,
      );
      if (!mapped.recordedWeightAvailable) {
        ingredientsAvailable = false;
        deliveryAvailable = false;
        nutritionAvailable = false;
        continue;
      }
      nutritionAvailable &= !mapped.consumedHistoricalNutritionUnavailable;
      consumedIngredients.add((
        name: mapped.ingredientName,
        grams: mapped.consumedTotalGrams,
      ));
      final amount = mapped.consumedNetCarbsContribution;
      if (!amount.isFinite || amount < 0) {
        deliveryAvailable = false;
        nutritionAvailable = false;
        continue;
      }
      carbs += amount;
    }
    final explicitCarbs = context?.recordedCarbs?.toDouble();
    final snapshotCarbs = consumedSnapshot?.totalNetCarbsG;
    final validSnapshotCarbs =
        snapshotCarbs != null && snapshotCarbs.isFinite && snapshotCarbs >= 0
        ? snapshotCarbs
        : null;
    final historicalCarbs =
        explicitCarbs ??
        validSnapshotCarbs ??
        (nutritionAvailable ? carbs : null);
    final deliverySource =
        explicitCarbs ??
        validSnapshotCarbs ??
        (deliveryAvailable ? carbs : null);
    final suggested = context?.suggestedCarbs;
    return RecordedLowTreatment(
      ingredients: List.unmodifiable(consumedIngredients),
      mealId: meal.id,
      eatenAt: DateTime.fromMillisecondsSinceEpoch(meal.plannedAt),
      historicalNutritionCarbsGrams: historicalCarbs,
      historicalNutritionUnavailable: historicalCarbs == null,
      ingredientsAvailable: ingredientsAvailable,
      snapshotHistoryAvailable: snapshotHistory.available,
      netCarbsGrams:
          explicitCarbs ??
          (deliverySource == null
              ? null
              : deliverySource >= 0.5
              ? lowTreatmentDeliveryCarbs(deliverySource)
              : 0.0),
      reason: context?.reason,
      source: context?.source,
      relatedMealId: context?.relatedMealId,
      relatedActivityLogId: context?.relatedActivityLogId,
      suggestedCarbs: suggested != null && suggested.isFinite && suggested >= 0
          ? suggested
          : null,
    );
  }
}
