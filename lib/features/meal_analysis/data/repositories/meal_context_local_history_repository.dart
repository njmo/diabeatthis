import 'package:drift/drift.dart';

import '../../../../common/monitoring/effective_activity_duration.dart';
import '../../../../core/domain/model/meal_snapshot.dart';
import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/mappers/meal_snapshot_drift_mapper.dart';
import '../../domain/models/meal_activity_context.dart';
import '../../domain/models/meal_composition.dart';
import '../../domain/models/recorded_meal_context.dart';

class MealContextLocalHistoryRepository {
  final DatabaseImpl db;
  const MealContextLocalHistoryRepository(this.db);

  Future<List<RecordedMealContext>> loadMeals(
    DateTime start,
    DateTime cutoff,
    int? excludeMealId,
  ) => db.transaction(() async {
    final rows = await db
        .customSelect(
          '''
      SELECT * FROM (
        SELECT m.id, m.name, COALESCE(
          (SELECT MIN(h.created_at) FROM meal_status_history h WHERE h.meal_id = m.id
           AND h.status IN ('eating', 'eating-then-bolus', 'bolused-eating', 'waited-eating')),
          CASE WHEN m.updated_at <= ? AND m.status IN
            ('eaten', 'eaten-extra', 'eaten-bolused', 'summarized')
          THEN COALESCE(m.summarized_at, m.planned_at) END
        ) AS eaten_at
        FROM meal m WHERE m.purpose = 'meal'
      ) WHERE eaten_at >= ? AND eaten_at < ?
    ''',
          variables: [
            Variable.withInt(cutoff.millisecondsSinceEpoch),
            Variable.withInt(start.millisecondsSinceEpoch),
            Variable.withInt(cutoff.millisecondsSinceEpoch),
          ],
          readsFrom: {db.meal, db.mealStatusHistory},
        )
        .get();
    final ids = rows
        .map((r) => r.read<int>('id'))
        .where((id) => id != excludeMealId)
        .toList();
    if (ids.isEmpty) return [];
    final query = db.select(db.mealSnapshot)
      ..where(
        (s) =>
            s.mealId.isIn(ids) &
            s.createdAt.isSmallerOrEqualValue(cutoff.millisecondsSinceEpoch) &
            s.updatedAt.isSmallerOrEqualValue(cutoff.millisecondsSinceEpoch),
      );
    final snapshots = await query.get();
    final byMeal = <int, MealSnapshotData>{};
    for (final snapshot in snapshots) {
      if (byMeal[snapshot.mealId] == null ||
          snapshot.snapshotType == 'consumed') {
        byMeal[snapshot.mealId] = snapshot;
      }
    }
    return rows
        .where((r) => r.read<int>('id') != excludeMealId)
        .map(
          (row) => RecordedMealContext(
            mealId: row.read<int>('id'),
            name: row.read<String>('name'),
            eatenAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('eaten_at'),
            ),
            snapshot: byMeal[row.read<int>('id')]?.toDomain(),
          ),
        )
        .toList();
  });

  /// Batch ingredient read only for similarity search; regular contexts stay cheap.
  /// Portion conversions are current because they have no revision history.
  Future<List<RecordedMealContext>> loadSimilarMeals(
    DateTime start,
    DateTime cutoff,
    int? excludeMealId,
  ) => db.transaction(() async {
    final meals = await loadMeals(start, cutoff, excludeMealId);
    if (meals.isEmpty) return meals;
    final rows = await db
        .customSelect(
          '''SELECT mi.*, i.is_reference,
      ip.grams_per_portion FROM meal_ingredients mi
      JOIN ingredient i ON i.id = mi.ingredient_id
      LEFT JOIN ingredient_portions ip ON ip.ingredient_id = mi.ingredient_id AND ip.portion_id = mi.portion_id
      WHERE mi.meal_id IN (${List.filled(meals.length, '?').join(',')})''',
          variables: [for (final meal in meals) Variable.withInt(meal.mealId)],
        )
        .get();
    final ingredientsByMeal = <int, List<QueryRow>>{};
    for (final row in rows) {
      (ingredientsByMeal[row.read<int>('meal_id')] ??= []).add(row);
    }
    final result = <RecordedMealContext>[];
    for (final meal in meals) {
      final ingredients = ingredientsByMeal[meal.mealId] ?? const <QueryRow>[];
      final grams = <int, double>{};
      var valid = true;
      for (final row in ingredients) {
        if (row.read<int>('updated_at') > cutoff.millisecondsSinceEpoch ||
            row.read<int>('created_at') > cutoff.millisecondsSinceEpoch) {
          valid = false;
          break;
        }
        final extra = row.read<String>('entry_type') == 'extra';
        final consumed =
            meal.snapshot?.snapshotType == MealSnapshotType.consumed;
        if (!consumed && extra) continue;
        final amount = consumed
            ? row.readNullable<double>('consumed_amount') ??
                  (extra ? 0 : row.read<double>('amount'))
            : row.read<double>('amount');
        final conversion = row.read<int>('is_reference') == 1
            ? 100.0
            : row.readNullable<int>('portion_id') == null
            ? 1.0
            : row.readNullable<double>('grams_per_portion');
        if (conversion == null || !amount.isFinite || amount < 0) {
          valid = false;
          break;
        }
        if (amount == 0) continue;
        final id = row.read<int>('ingredient_id');
        grams[id] = (grams[id] ?? 0) + amount * conversion;
      }
      result.add(
        RecordedMealContext(
          mealId: meal.mealId,
          name: meal.name,
          eatenAt: meal.eatenAt,
          snapshot: meal.snapshot,
          composition: valid && grams.isNotEmpty
              ? MealComposition(grams)
              : null,
        ),
      );
    }
    return result;
  });

  Future<List<MealActivityContext>> loadActivities(
    DateTime start,
    DateTime end,
    DateTime cutoff,
  ) async {
    final rows = await db.activityDao.getActivityLogsOverlapping(start, end);
    return rows
        .where((r) => r.log.createdAt <= cutoff.millisecondsSinceEpoch)
        .map((row) {
          final ended = row.log.endedAt;
          return MealActivityContext(
            logId: row.log.id,
            name: row.activity.name,
            startedAt: DateTime.fromMillisecondsSinceEpoch(row.log.startedAt),
            endedAt: ended == null || ended > cutoff.millisecondsSinceEpoch
                ? null
                : DateTime.fromMillisecondsSinceEpoch(ended),
            recordedAt: DateTime.fromMillisecondsSinceEpoch(row.log.createdAt),
            plannedDurationMinutes: effectiveActivityDuration(
              activityDuration: row.activity.durationMinutes,
              hasScheduledOccurrence: row.occurrence != null,
              occurrenceDuration: row.occurrence?.durationMinutes,
            ),
            percentagePre: row.activity.percentagePre,
            percentagePost: row.activity.percentagePost,
          );
        })
        .toList();
  }
}
