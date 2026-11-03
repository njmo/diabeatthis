import '../../../../../common/monitoring/activity_duration_source.dart';
import '../../../../../common/monitoring/effective_activity_duration.dart';
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
  final occurrence = await db.activityDao.getOccurrenceForLog(log.id);

  return ActivityMonitorContext(
    activityLogId: log.id,
    activityId: log.activityId,
    activityName: activity.name,
    startsAt: DateTime.fromMillisecondsSinceEpoch(log.startedAt),
    durationMinutes: effectiveActivityDuration(
      activityDuration: activity.durationMinutes,
      hasScheduledOccurrence: occurrence != null,
      occurrenceDuration: occurrence?.durationMinutes,
    ),
    durationSource: occurrence == null
        ? ActivityDurationSource.definition
        : ActivityDurationSource.occurrence,
  );
}
