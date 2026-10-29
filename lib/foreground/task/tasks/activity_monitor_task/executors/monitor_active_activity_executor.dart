import 'package:clock/clock.dart';

import '../../../../../common/monitoring/activity_monitoring_phase.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../features/activity/data/domain/use_cases/auto_finish_activity_use_case.dart';
import '../../../../event/internal/activity_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';
import '../helpers/activity_temp_target_monitor.dart';
import 'activity_monitor_state_executor.dart';
import 'finish_activity_executor.dart';

class MonitorActiveActivityExecutor extends ActivityMonitorStateExecutor {
  const MonitorActiveActivityExecutor();

  @override
  List<Type> get interruptableEvents => [
    NextActivityEvent,
    ActivityStoppedEvent,
    ActivityCancelledEvent,
  ];

  @override
  bool shouldInterrupt(
    ForegroundEvent event,
    ActivityMonitorContext activityMonitorContext,
  ) {
    logI("MonitorActiveActivityExecutor shouldInterrupt ${event.runtimeType}");
    switch (event) {
      case ActivityStoppedEvent():
        return event.activityLogId == activityMonitorContext.activityLogId;
      case ActivityCancelledEvent():
        return event.activityLogId == activityMonitorContext.activityLogId;
      case NextActivityEvent():
        return false;
      default:
        return false;
    }
  }

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    logI("MonitorActiveActivityExecutor cleanup");
  }

  @override
  Future<ActivityMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    activityMonitorContext.publishStatus(
      runtimeContext,
      ActivityMonitoringPhase.active,
    );
    logI("MonitorActiveActivityExecutor");

    final activityLogId = activityMonitorContext.activityLogId;
    if (activityLogId == null) {
      return const FinishActivityExecutor();
    }

    final targets = runtimeContext.container.read(
      activityTempTargetMonitorProvider,
    );
    final superviseTargets = await targets.isEnabled(runtimeContext);
    final durationMinutes = activityMonitorContext.durationMinutes;
    if (durationMinutes == null || durationMinutes <= 0) {
      logI("Activity has manual duration, waiting for stop event");
      if (superviseTargets) {
        await targets.waitUntil(
          runtimeContext,
          null,
          activityLogId: activityLogId,
        );
      } else {
        await runtimeContext.waitForEvent<ForegroundEvent>(
          predicate: (event) => _isActivityClosedEvent(event, activityLogId),
        );
      }
      return const FinishActivityExecutor();
    }

    final startsAt = activityMonitorContext.startsAt;
    if (startsAt == null) return const FinishActivityExecutor();
    final endsAt = startsAt.add(Duration(minutes: durationMinutes));
    if (endsAt.isAfter(clock.now())) {
      if (superviseTargets) {
        await targets.waitUntil(
          runtimeContext,
          endsAt,
          activityLogId: activityLogId,
        );
      } else {
        await runtimeContext.waitUntil(endsAt);
      }
    }
    runtimeContext.throwIfCancelled();
    final db = runtimeContext.container.read(databaseProvider);
    await AutoFinishActivityUseCase(
      now: clock.now,
      finishIfOpen: db.activityDao.finishActivityLogIfOpen,
    )(
      activityLogId: activityLogId,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
    );
    return const FinishActivityExecutor();
  }

  bool _isActivityClosedEvent(ForegroundEvent event, int activityLogId) {
    return event is ActivityStoppedEvent &&
            event.activityLogId == activityLogId ||
        event is ActivityCancelledEvent && event.activityLogId == activityLogId;
  }
}
