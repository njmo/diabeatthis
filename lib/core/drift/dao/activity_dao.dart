import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'activity_dao.g.dart';

@DriftAccessor(
  include: {
    '../schemas/tables/activity.drift',
    '../schemas/tables/activity_log.drift',
  },
)
class ActivityDao extends DatabaseAccessor<DatabaseImpl>
    with _$ActivityDaoMixin {
  ActivityDao(super.db);

  Future<ActivityData?> insertActivity(ActivityCompanion activity) async {
    return into(db.activity).insertReturningOrNull(activity);
  }

  Future<List<ActivityLogData>> getActivityLogs({int page = 0}) async {
    return (select(db.activityLog)
          ..orderBy([(log) => OrderingTerm.desc(log.startedAt)])
          ..limit(10, offset: page * 10))
        .get();
  }

  Future<List<TypedResult>> getActivityLogsOverlapping(
    DateTime start,
    DateTime end,
  ) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final query =
        select(db.activityLog).join([
            innerJoin(
              db.activity,
              db.activity.id.equalsExp(db.activityLog.activityId),
            ),
          ])
          ..where(db.activityLog.startedAt.isSmallerThanValue(endMs))
          ..where(
            db.activityLog.endedAt.isNull() |
                db.activityLog.endedAt.isBiggerThanValue(startMs),
          )
          ..orderBy([OrderingTerm(expression: db.activityLog.startedAt)]);

    return query.get();
  }

  Future<ActivityLogData> getActivityLogById(int id) {
    return (select(
      db.activityLog,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Future<ActivityLogData> insertActivityLog(
    ActivityLogCompanion activityLog,
  ) async {
    return into(db.activityLog).insertReturning(activityLog);
  }

  Future<ActivityLogData> getActiveActivityLog() {
    return (select(
      db.activityLog,
    )..where((tbl) => tbl.endedAt.isNull())).getSingle();
  }

  Future<ActivityData> getActivityById(int id) {
    return (select(db.activity)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Future<void> updateActivityLog(ActivityLogCompanion activityLog) async {
    await into(db.activityLog).insertOnConflictUpdate(activityLog);
  }

  Future<void> removeActivityLog(ActivityLogCompanion companion) async {
    await (delete(
      db.activityLog,
    )..where((tbl) => tbl.id.equals(companion.id.value))).go();
  }
}
