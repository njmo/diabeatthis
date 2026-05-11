import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;

import '../../../../../common/events/data/notification/activity_finished_response_event.dart';
import '../../../../../core/drift/entity/activity.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/notifications/domain/events/activity_finished_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../event/internal/activity_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';
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
    logI("MonitorActiveActivityExecutor");

    final activityLogId = activityMonitorContext.activityLogId;
    if (activityLogId == null) {
      return const FinishActivityExecutor();
    }

    final durationMinutes = activityMonitorContext.durationMinutes;
    if (durationMinutes == null) {
      logI("Activity has manual duration, waiting for stop event");
      await runtimeContext.waitForEvent<ForegroundEvent>(
        predicate: (event) => _isActivityClosedEvent(event, activityLogId),
      );
      return const FinishActivityExecutor();
    }

    if (!activityMonitorContext.finishReminderShown) {
      final startsAt = activityMonitorContext.startsAt ?? clock.now();
      final endsAt = startsAt.add(Duration(minutes: durationMinutes));
      final waitTime = endsAt.difference(clock.now());

      if (waitTime > Duration.zero) {
        logI(
          "Sleeping until activity planned end in ${waitTime.inMinutes} minutes",
        );
        await runtimeContext.waitForDuration(waitTime);
      }

      await _showFinishedNotification(runtimeContext, activityMonitorContext);
      activityMonitorContext.finishReminderShown = true;
    }

    final response = await runtimeContext
        .waitForEvent<ActivityFinishedResponseEvent>(
          predicate: (event) => event.activityLogId == activityLogId,
        );

    return response.when(
      agree: (_) async {
        await _finishActivity(runtimeContext, activityLogId);
        return const FinishActivityExecutor();
      },
      dismiss: (_) async {
        logI("User will finish activity manually");
        await runtimeContext.waitForEvent<ForegroundEvent>(
          predicate: (event) => _isActivityClosedEvent(event, activityLogId),
        );
        return const FinishActivityExecutor();
      },
      empty: (_) async {
        logI("User opened activity finished notification");
        activityMonitorContext.finishReminderShown = false;
        return this;
      },
    );
  }

  Future<void> _showFinishedNotification(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    final activityLogId = activityMonitorContext.activityLogId;
    if (activityLogId == null) return;

    final notificationProvider = runtimeContext.container.read(
      notificationsControllerForegroundProvider,
    );
    await notificationProvider.show(
      ActivityFinishedNotificationEvent(
        activityLogId: activityLogId,
        activityName: activityMonitorContext.activityName ?? 'Aktywność',
      ),
    );
  }

  Future<void> _finishActivity(
    RuntimeContext runtimeContext,
    int activityLogId,
  ) async {
    final db = runtimeContext.container.read(databaseProvider);
    final log = await db.activityDao.getActivityLogByIdOrNull(activityLogId);
    if (log == null || log.endedAt != null) {
      return;
    }

    if (DateTime.fromMillisecondsSinceEpoch(
      log.startedAt,
    ).isAfter(clock.now())) {
      await db.activityDao.removeActivityLog(
        ActivityLogCompanion(id: Value(activityLogId)),
      );
      return;
    }

    await db.activityDao.updateActivityLog(
      ActivityLogCompanion(
        id: Value(log.id),
        activityId: Value(log.activityId),
        startedAt: Value(log.startedAt),
        endedAt: Value(clock.now().millisecondsSinceEpoch),
      ),
    );
  }

  bool _isActivityClosedEvent(ForegroundEvent event, int activityLogId) {
    return event is ActivityStoppedEvent &&
            event.activityLogId == activityLogId ||
        event is ActivityCancelledEvent && event.activityLogId == activityLogId;
  }
}
