import 'package:clock/clock.dart';

import '../../../../../core/drift/providers/database_provider.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';
import 'activity_monitor_state_executor.dart';
import 'idle_executor.dart';
import 'monitor_active_activity_executor.dart';
import 'monitor_until_activity_executor.dart';

class NewActivityCheckExecutor extends ActivityMonitorStateExecutor {
  const NewActivityCheckExecutor();

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    logI("NewActivityCheckExecutor cleanup");
  }

  @override
  Future<ActivityMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    logI("NewActivityCheckExecutor");

    final db = runtimeContext.container.read(databaseProvider);
    final nextLog = await db.activityDao.getNearestActivityLog();
    if (nextLog == null) {
      activityMonitorContext.clear();
      logI("No activity to monitor");
      return const ActivityMonitorStateIdle();
    }

    final activity = await db.activityDao.getActivityById(nextLog.activityId);
    activityMonitorContext.replaceWith(
      ActivityMonitorContext(
        activityLogId: nextLog.id,
        activityId: nextLog.activityId,
        activityName: activity.name,
        startsAt: DateTime.fromMillisecondsSinceEpoch(nextLog.startedAt),
        durationMinutes: activity.durationMinutes,
      ),
    );

    if (activityMonitorContext.startsAt!.isAfter(clock.now())) {
      return const MonitorUntilActivityExecutor();
    }

    return const MonitorActiveActivityExecutor();
  }
}
