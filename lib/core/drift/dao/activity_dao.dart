import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'activity_dao.g.dart';

typedef ActivityLogViewData = ({ActivityLogData log, ActivityData activity});

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

  Future<ActivityData> updateActivity(ActivityCompanion activity) async {
    await update(db.activity).replace(activity);
    return getActivityById(activity.id.value);
  }

  Stream<List<ActivityData>> watchActivities({int? limit}) {
    final query = select(db.activity)
      ..orderBy([(activity) => OrderingTerm.asc(activity.name)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  Stream<List<ActivityLogViewData>> watchActivityLogViews({
    int? activityId,
    int? limit,
  }) {
    final query =
        select(db.activityLog).join([
          innerJoin(
            db.activity,
            db.activity.id.equalsExp(db.activityLog.activityId),
          ),
        ])..orderBy([
          OrderingTerm(
            expression: db.activityLog.startedAt,
            mode: OrderingMode.desc,
          ),
        ]);

    if (activityId != null) {
      query.where(db.activityLog.activityId.equals(activityId));
    }
    if (limit != null) {
      query.limit(limit);
    }

    return query.watch().map((rows) => rows.map(_activityLogViewData).toList());
  }

  Future<List<ActivityLogViewData>> getActivityLogsOverlapping(
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

    return query.get().then((rows) => rows.map(_activityLogViewData).toList());
  }

  Future<ActivityLogData> getActivityLogById(int id) {
    return (select(
      db.activityLog,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Future<ActivityLogData?> getActivityLogByIdOrNull(int id) {
    return (select(
      db.activityLog,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<ActivityLogData> insertActivityLog(
    ActivityLogCompanion activityLog,
  ) async {
    return into(db.activityLog).insertReturning(activityLog);
  }

  Future<ActivityLogData?> getActiveActivityLogOrNull() {
    return (select(
      db.activityLog,
    )..where((tbl) => tbl.endedAt.isNull())).getSingleOrNull();
  }

  Future<ActivityLogViewData?> getActiveActivityLogView() async {
    final query =
        select(db.activityLog).join([
            innerJoin(
              db.activity,
              db.activity.id.equalsExp(db.activityLog.activityId),
            ),
          ])
          ..where(db.activityLog.endedAt.isNull())
          ..orderBy([OrderingTerm.asc(db.activityLog.startedAt)])
          ..limit(1);

    final row = await query.getSingleOrNull();
    return row == null ? null : _activityLogViewData(row);
  }

  Stream<ActivityLogViewData?> watchActiveActivityLogView() {
    final query =
        select(db.activityLog).join([
            innerJoin(
              db.activity,
              db.activity.id.equalsExp(db.activityLog.activityId),
            ),
          ])
          ..where(db.activityLog.endedAt.isNull())
          ..orderBy([OrderingTerm.asc(db.activityLog.startedAt)])
          ..limit(1);

    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _activityLogViewData(row),
    );
  }

  Future<ActivityLogData?> getNearestActivityLog() {
    final query = select(db.activityLog)
      ..where((tbl) => tbl.endedAt.isNull())
      ..orderBy([(log) => OrderingTerm.asc(log.startedAt)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Stream<List<ActivityLogData>> getAllPendingActivityLogs() {
    final query = select(db.activityLog)
      ..where((tbl) => tbl.endedAt.isNull())
      ..orderBy([(log) => OrderingTerm.asc(log.startedAt)]);

    return query.watch();
  }

  ActivityLogViewData _activityLogViewData(TypedResult row) {
    return (
      log: row.readTable(db.activityLog),
      activity: row.readTable(db.activity),
    );
  }

  Future<ActivityData> getActivityById(int id) {
    return (select(db.activity)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Stream<ActivityData?> watchActivityById(int id) {
    return (select(
      db.activity,
    )..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
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
