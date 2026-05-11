import '../../../../../core/drift/providers/database_provider.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';

Future<ActivityMonitorContext?> loadActivityMonitorContext(
  RuntimeContext context,
  int activityLogId,
) async {
  final db = context.container.read(databaseProvider);
  final log = await db.activityDao.getActivityLogByIdOrNull(activityLogId);
  if (log == null || log.endedAt != null) {
    return null;
  }

  final activity = await db.activityDao.getActivityById(log.activityId);

  return ActivityMonitorContext(
    activityLogId: log.id,
    activityId: log.activityId,
    activityName: activity.name,
    startsAt: DateTime.fromMillisecondsSinceEpoch(log.startedAt),
    durationMinutes: activity.durationMinutes,
  );
}
