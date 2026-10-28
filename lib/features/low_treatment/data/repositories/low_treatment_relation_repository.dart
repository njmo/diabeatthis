import '../../../../common/models/timeline_relation.dart';
import '../../../../core/drift/database_impl.dart';

class LowTreatmentRelationRepository {
  const LowTreatmentRelationRepository(this.db);
  final DatabaseImpl db;

  Future<List<TimelineRelation>> load(
    DateTime day,
    DateTime occurredAt, {
    int? excludeMealId,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final meals = await db.mealDao.getMealsBetween(
      start,
      end.subtract(const Duration(milliseconds: 1)),
      excludeMealId: excludeMealId,
    );
    final activities = await db.activityDao.getActivityLogsOverlapping(
      start,
      end,
    );
    final entries = [
      for (final meal in meals)
        TimelineRelation(
          id: meal.id,
          kind: TimelineRelationKind.meal,
          name: meal.name,
          at: DateTime.fromMillisecondsSinceEpoch(meal.plannedAt),
        ),
      for (final activity in activities)
        TimelineRelation(
          id: activity.log.id,
          kind: TimelineRelationKind.activity,
          name: activity.activity.name,
          at: DateTime.fromMillisecondsSinceEpoch(activity.log.startedAt),
        ),
    ];
    entries.sort((a, b) {
      final distance = a.at
          .difference(occurredAt)
          .abs()
          .compareTo(b.at.difference(occurredAt).abs());
      return distance != 0 ? distance : a.at.compareTo(b.at);
    });
    return entries;
  }

  Future<TimelineRelation?> resolve({int? mealId, int? activityLogId}) async {
    if (mealId != null) {
      final meal = await db.mealDao.getMealById(mealId);
      if (meal == null) return null;
      return TimelineRelation(
        id: meal.id,
        kind: TimelineRelationKind.meal,
        name: meal.name,
        at: DateTime.fromMillisecondsSinceEpoch(meal.plannedAt),
      );
    }
    if (activityLogId != null) {
      final log = await db.activityDao.getActivityLogByIdOrNull(activityLogId);
      if (log == null) return null;
      final activity = await db.activityDao.getActivityById(log.activityId);
      return TimelineRelation(
        id: log.id,
        kind: TimelineRelationKind.activity,
        name: activity.name,
        at: DateTime.fromMillisecondsSinceEpoch(log.startedAt),
      );
    }
    return null;
  }
}
