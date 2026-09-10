import 'package:drift/drift.dart';

import '../../../../core/drift/database_impl.dart';
import '../../domain/models/day_activity_summary.dart';
import '../../domain/models/day_meal_summary.dart';

class DayLocalHistoryRepository {
  final DatabaseImpl db;
  const DayLocalHistoryRepository(this.db);

  Future<DayMealSummary> loadMeals(DateTime start, DateTime end) async {
    // Use recorded eating start, even when the plan was on another day.
    final rows = await db
        .customSelect(
          '''
      SELECT m.id, COALESCE(c.total_net_carbs_g, p.total_net_carbs_g) AS carbs,
        COALESCE(c.total_protein_g, p.total_protein_g) AS protein,
        COALESCE(c.total_fat_g, p.total_fat_g) AS fat,
        c.id AS consumed_id, p.id AS planned_id
      FROM meal m
      LEFT JOIN meal_snapshot c ON c.meal_id = m.id AND c.snapshot_type = 'consumed'
      LEFT JOIN meal_snapshot p ON p.meal_id = m.id AND p.snapshot_type = 'planned'
      WHERE m.purpose = 'meal'
        AND m.status IN ('eating', 'eating-extra', 'eating-then-bolus',
          'waiting-for-bolus', 'waited-eating', 'bolused-eating',
          'eaten', 'eaten-extra', 'eaten-bolused', 'summarized')
        AND COALESCE((SELECT MIN(h.created_at) FROM meal_status_history h
          WHERE h.meal_id = m.id AND h.status IN
            ('eating', 'eating-then-bolus', 'bolused-eating', 'waited-eating')),
          m.summarized_at, m.planned_at) BETWEEN ? AND ?
    ''',
          variables: [
            Variable.withInt(start.millisecondsSinceEpoch),
            Variable.withInt(end.millisecondsSinceEpoch),
          ],
          readsFrom: {db.meal, db.mealSnapshot, db.mealStatusHistory},
        )
        .get();
    double total(String field) => rows.fold(
      0.0,
      (sum, row) => sum + (row.readNullable<double>(field) ?? 0),
    );
    return DayMealSummary(
      count: rows.length,
      plannedFallbackCount: rows
          .where(
            (r) =>
                r.readNullable<int>('consumed_id') == null &&
                r.readNullable<int>('planned_id') != null,
          )
          .length,
      missingSnapshotCount: rows
          .where(
            (r) =>
                r.readNullable<int>('consumed_id') == null &&
                r.readNullable<int>('planned_id') == null,
          )
          .length,
      netCarbs: total('carbs'),
      protein: total('protein'),
      fat: total('fat'),
    );
  }

  Future<List<DayActivitySummary>> loadActivities(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await db.activityDao.getActivityLogsOverlapping(start, end);
    return rows.map((row) {
      final began = DateTime.fromMillisecondsSinceEpoch(row.log.startedAt);
      final ended = row.log.endedAt == null
          ? end
          : DateTime.fromMillisecondsSinceEpoch(row.log.endedAt!);
      final from = began.isBefore(start) ? start : began;
      final until = ended.isAfter(end) ? end : ended;
      return DayActivitySummary(
        name: row.activity.name,
        observedDuration: until.isBefore(from)
            ? Duration.zero
            : until.difference(from),
        ongoing: row.log.endedAt == null || ended.isAfter(end),
      );
    }).toList();
  }
}
