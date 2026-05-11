import 'package:clock/clock.dart';

import '../../../../event/internal/activity_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';
import 'activity_monitor_state_executor.dart';
import 'monitor_active_activity_executor.dart';

class MonitorUntilActivityExecutor extends ActivityMonitorStateExecutor {
  const MonitorUntilActivityExecutor();

  @override
  List<Type> get interruptableEvents => [
    NextActivityEvent,
    ActivityStartedEvent,
    ActivityStoppedEvent,
    ActivityCancelledEvent,
  ];

  @override
  bool shouldInterrupt(
    ForegroundEvent event,
    ActivityMonitorContext activityMonitorContext,
  ) {
    logI("MonitorUntilActivityExecutor shouldInterrupt ${event.runtimeType}");
    switch (event) {
      case NextActivityEvent():
        return event.activityLogId != activityMonitorContext.activityLogId;
      case ActivityStartedEvent():
        return event.activityLogId == activityMonitorContext.activityLogId;
      case ActivityStoppedEvent():
        return event.activityLogId == activityMonitorContext.activityLogId;
      case ActivityCancelledEvent():
        return event.activityLogId == activityMonitorContext.activityLogId;
      default:
        return false;
    }
  }

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    logI("MonitorUntilActivityExecutor cleanup");
  }

  @override
  Future<ActivityMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    logI("MonitorUntilActivityExecutor");

    final startsAt = activityMonitorContext.startsAt;
    if (startsAt == null) {
      return const MonitorActiveActivityExecutor();
    }

    final waitTime = startsAt.difference(clock.now());
    if (waitTime <= Duration.zero) {
      return const MonitorActiveActivityExecutor();
    }

    logI("Sleeping until activity starts in ${waitTime.inMinutes} minutes");
    await runtimeContext.waitForDuration(waitTime);

    return const MonitorActiveActivityExecutor();
  }
}
