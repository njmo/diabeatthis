import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/meal/meal_add_on_bolus_progress.dart';
import '../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../common/meal/meal_completion_timing.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';

class MealCompletionContext {
  const MealCompletionContext({
    required this.meal,
    required this.timing,
    this.hasRecordedBolus = false,
    this.requiresBolus = false,
    this.coveredNetCarbs,
    this.bolusCoverage,
  });

  final Meal meal;
  final MealCompletionTiming timing;
  final bool hasRecordedBolus;
  final bool requiresBolus;
  final double? coveredNetCarbs;
  final MealBolusCoverage? bolusCoverage;
}

final mealCompletionContextProvider = FutureProvider.autoDispose
    .family<MealCompletionContext, int>((ref, mealId) async {
      final db = ref.watch(databaseProvider);
      final meal = await db.mealDao.getMealById(mealId);
      if (meal == null) throw StateError('Meal not found');
      final history = await (db.select(
        db.mealStatusHistory,
      )..where((row) => row.mealId.equals(mealId))).get();
      // Include accepted calculator responses that arrived before the monitor
      // linked them, so a stale-save retry reviews the same facts as the write.
      final addOn = await reconcileMealAddOnBolusProgress(db, mealId);
      final coverage = await readMealBolusCoverage(db, mealId, context: addOn);
      final timing = MealCompletionTiming.fromHistory(
        history.map(
          (entry) => (
            status: entry.status,
            at: DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
          ),
        ),
        currentStatus: meal.status,
      );
      return MealCompletionContext(
        meal: meal.toDomain(),
        hasRecordedBolus: coverage.hasRecordedBolus,
        bolusCoverage: coverage,
        coveredNetCarbs: addOn == null ? null : coverage.carbs,
        requiresBolus:
            meal.status == 'eating-then-bolus' ||
            (addOn?.awaitingBolus ?? false),
        timing: addOn == null
            ? timing
            : MealCompletionTiming(
                startedAt: addOn.eatingStartedAt,
                endedAt: timing.endedAt,
                endStatus: timing.endStatus,
                isAddOn: true,
              ),
      );
    });
