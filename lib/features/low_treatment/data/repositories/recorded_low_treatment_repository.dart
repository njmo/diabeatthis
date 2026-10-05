import 'package:drift/drift.dart';

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
    final mapper = MealDetailsDataMapper(db: db);
    var carbs = ingredients.isEmpty ? null : 0.0;
    for (final ingredient in ingredients) {
      final mapped = await mapper.mapIngredient(
        meal: meal,
        mealIngredient: ingredient,
        plannedSnapshot: null,
        consumedSnapshot: null,
      );
      final amount = mapped.consumedNetCarbsContribution;
      if (!amount.isFinite || amount < 0) {
        carbs = null;
        break;
      }
      carbs = carbs! + amount;
    }
    final suggested = context?.suggestedCarbs;
    return RecordedLowTreatment(
      mealId: meal.id,
      eatenAt: DateTime.fromMillisecondsSinceEpoch(meal.plannedAt),
      netCarbsGrams: carbs,
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
