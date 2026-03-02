import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'activity_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/activity.drift', '../schemas/tables/activity_log.drift'})
class ActivityDao extends DatabaseAccessor<DatabaseImpl>
    with _$ActivityDaoMixin {
  ActivityDao(super.db);

  Future<ActivityData?> insertActivity(ActivityCompanion activity) async {
    return into(db.activity).insertReturningOrNull(activity);
  }

  Future<ActivityLogData> insertActivityLog(ActivityLogCompanion activityLog) async {
    return into(db.activityLog).insertReturning(activityLog);
  }

  Future<ActivityLogData> getActiveActivityLog() {
    return (select(db.activityLog)..where((tbl) => tbl.endedAt.isNull())).getSingle();
  }

  Future<ActivityData> getActivityById(int id) {
    return (select(db.activity)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Future<void> updateActivityLog(ActivityLogCompanion activityLog) async {
    await into(db.activityLog).insertOnConflictUpdate(activityLog);
  }
}
