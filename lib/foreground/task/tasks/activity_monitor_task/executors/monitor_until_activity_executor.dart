import 'package:clock/clock.dart';

import '../../../../../core/domain/model/temporary_target.dart';
import '../../../../../core/notifications/domain/events/temp_target_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../event/internal/activity_event.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';
import 'activity_monitor_state_executor.dart';
import 'monitor_active_activity_executor.dart';

class MonitorUntilActivityExecutor extends ActivityMonitorStateExecutor {
  const MonitorUntilActivityExecutor();

  static const tempTargetSuggestionLeadTime = Duration(minutes: 45);
  static const tempTargetSuggestionRetryInterval = Duration(minutes: 5);

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

    final timeToActivity = startsAt.difference(clock.now());
    if (timeToActivity <= Duration.zero) {
      return const MonitorActiveActivityExecutor();
    }

    if (timeToActivity > tempTargetSuggestionLeadTime) {
      final waitTime = timeToActivity - tempTargetSuggestionLeadTime;
      logI(
        "Sleeping until activity temp target window in "
        "${waitTime.inMinutes} minutes",
      );
      await runtimeContext.waitForDuration(waitTime);
    }

    while (startsAt.isAfter(clock.now())) {
      final activityLogId = activityMonitorContext.activityLogId;
      if (activityLogId == null) {
        return const MonitorActiveActivityExecutor();
      }

      logI("Showing activity temp target suggestion");
      await runtimeContext.container
          .read(notificationsControllerForegroundProvider)
          .show(TempTargetNotificationEvent.activity(entityId: activityLogId));

      final remaining = startsAt.difference(clock.now());
      final waitTime = remaining < tempTargetSuggestionRetryInterval
          ? remaining
          : tempTargetSuggestionRetryInterval;
      final targetEvent = await runtimeContext
          .waitForEventWithTimeoutOrNull<
            TreatmentAvailableEvent<TemporaryTarget>
          >(waitTime);

      if (targetEvent != null) {
        logI("Activity temp target detected, waiting for activity start");
        await runtimeContext.waitUntil(startsAt);
        break;
      }
    }

    return const MonitorActiveActivityExecutor();
  }
}
