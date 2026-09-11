import 'package:drift/drift.dart';

import '../../../../core/drift/database_impl.dart';
import '../../domain/models/day_activity_summary.dart';
import '../../domain/models/day_meal_summary.dart';
import '../../domain/models/day_recorded_meal.dart';

class DayLocalHistoryRepository {
  final DatabaseImpl db;
  const DayLocalHistoryRepository(this.db);

  Future<DayMealSummary> loadMeals(DateTime start, DateTime end) async {
    final rows = await _mealRows(start, end);
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

  Future<List<DayRecordedMeal>> loadRecordedMeals(
    DateTime start,
    DateTime end, {
    List<int> includeIds = const [],
    bool includeUnstarted = false,
  }) async =>
      (await _mealRows(
            start,
            end,
            includeIds: includeIds,
            includeUnstarted: includeUnstarted,
          ))
          .map(
            (row) => DayRecordedMeal(
              requiresCompletion: [
                'planned',
                'skipped',
              ].contains(row.read<String>('status')),
              id: row.read<int>('id'),
              name: row.read<String>('name'),
              eatenAt: DateTime.fromMillisecondsSinceEpoch(
                row.read<int>('eaten_at'),
              ),
            ),
          )
          .toList()
        ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));

  Future<List<DayRecordedMeal>> loadMealCandidates(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(
      date.year,
      date.month,
      date.day + 1,
    ).subtract(const Duration(milliseconds: 1));
    return loadRecordedMeals(start, end, includeUnstarted: true);
  }

  // One definition of recorded eating time for statistics and day review.
  Future<List<QueryRow>> _mealRows(
    DateTime start,
    DateTime end, {
    List<int> includeIds = const [],
    bool includeUnstarted = false,
  }) {
    const eatingTime =
        """COALESCE((SELECT MIN(h.created_at) FROM meal_status_history h
          WHERE h.meal_id = m.id AND h.status IN
            ('eating', 'eating-then-bolus', 'bolused-eating', 'waited-eating')),
          m.summarized_at, m.planned_at)""";
    return db
        .customSelect(
          '''
      SELECT m.id, m.name, m.status, $eatingTime AS eaten_at, COALESCE(c.total_net_carbs_g, p.total_net_carbs_g) AS carbs,
        COALESCE(c.total_protein_g, p.total_protein_g) AS protein,
        COALESCE(c.total_fat_g, p.total_fat_g) AS fat,
        c.id AS consumed_id, p.id AS planned_id
      FROM meal m
      LEFT JOIN meal_snapshot c ON c.meal_id = m.id AND c.snapshot_type = 'consumed'
      LEFT JOIN meal_snapshot p ON p.meal_id = m.id AND p.snapshot_type = 'planned'
      WHERE m.purpose = 'meal'
        AND ((m.status IN ('eating', 'eating-extra', 'eating-then-bolus',
          'waiting-for-bolus', 'waited-eating', 'bolused-eating',
          'eaten', 'eaten-extra', 'eaten-bolused', 'summarized'
          ${includeUnstarted ? ", 'planned', 'skipped'" : ''})
        AND $eatingTime BETWEEN ? AND ?)
          ${includeIds.isEmpty ? '' : 'OR m.id IN (${List.filled(includeIds.length, '?').join(',')})'})
    ''',
          variables: [
            Variable.withInt(start.millisecondsSinceEpoch),
            Variable.withInt(end.millisecondsSinceEpoch),
            ...includeIds.map(Variable.withInt),
          ],
          readsFrom: {db.meal, db.mealSnapshot, db.mealStatusHistory},
        )
        .get();
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
