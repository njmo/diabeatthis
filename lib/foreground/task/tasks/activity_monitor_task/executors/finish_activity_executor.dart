import '../../../../../common/monitoring/activity_monitoring_phase.dart';
import '../../../../../common/notifications/scoped_notification_cancellation.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/notifications/domain/events/temp_target_notification.dart';
import '../../../../../core/notifications/domain/models/notification_event_type.dart';
import '../../../../../core/notifications/domain/models/notification_key.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';
import '../helpers/activity_temp_target_monitor.dart';
import 'activity_monitor_state_executor.dart';
import 'new_activity_check_executor.dart';

class FinishActivityExecutor extends ActivityMonitorStateExecutor {
  const FinishActivityExecutor();

  @override
  List<Type> get interruptableEvents => [];

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    logI("FinishActivityExecutor cleanup");
  }

  @override
  Future<ActivityMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    activityMonitorContext.publishStatus(
      runtimeContext,
      ActivityMonitoringPhase.idle,
    );
    logI("FinishActivityExecutor");
    final activityLogId = activityMonitorContext.activityLogId;
    activityMonitorContext.clear();

    if (activityLogId != null) {
      final notifications = runtimeContext.container.read(
        notificationsControllerForegroundProvider,
      );
      await notifications.cancelNotification(
        TempTargetNotificationEvent.activity(entityId: activityLogId).key,
      );
      await notifications.cancelNotification(
        NotificationKey(
          type: NotificationEventType.activityFinished,
          entityId: activityLogId,
        ),
      );
      final occurrence = await runtimeContext.container
          .read(databaseProvider)
          .activityDao
          .getOccurrenceForLog(activityLogId);
      if (occurrence != null) {
        await notifications.cancelNotification(
          NotificationKey(
            type: NotificationEventType.activitySchedule,
            entityId: occurrence.id,
          ),
        );
      }
    }

    await runtimeContext.container
        .read(activityTempTargetMonitorProvider)
        .reconcile(runtimeContext);

    return const NewActivityCheckExecutor();
  }
}
