import 'package:drift/drift.dart';

import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/mappers/meal_snapshot_drift_mapper.dart';
import '../../domain/models/meal_activity_context.dart';
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
            plannedDurationMinutes: row.activity.durationMinutes,
            percentagePre: row.activity.percentagePre,
            percentagePost: row.activity.percentagePost,
          );
        })
        .toList();
  }
}
