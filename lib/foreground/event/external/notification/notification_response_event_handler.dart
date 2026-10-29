import 'dart:async';

import '../../../../common/events/data/notification/aaps_carbs_request_response_event.dart';
import '../../../../common/events/data/notification/activity_finished_response_event.dart';
import '../../../../common/events/data/notification/activity_schedule_response_event.dart';
import '../../../../common/events/data/notification/finished_eating_response_event.dart';
import '../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../common/events/data/notification/meal_summary_reminder_response_event.dart';
import '../../../../common/events/data/notification/temp_target_response_event.dart';
import '../../../../common/events/data/task/task_open_low_treatment_payload.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import '../../../../core/logger/logger.dart';
import '../../../../core/notifications/domain/events/temp_target_delivery_notification.dart';
import '../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../features/activity/data/services/activity_schedule_service.dart';
import '../../../../features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import '../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../providers/task_event_router_provider.dart';
import '../../../task/base/runtime_context.dart';
import '../../internal/aaps_carbs_request_acknowledged_event.dart';
import 'notification_response_event.dart';

class NotificationResponseEventHandler with Logging {
  NotificationResponseEventHandler();

  void handle(NotificationResponseEvent event, RuntimeContext context) {
    event.when(
      activityScheduleResponse: (data) =>
          unawaited(_handleActivitySchedule(data, context)),
      eatNowResponse: (data) => context.emitEvent(data),
      tempTargetResponse: (TempTargetResponseEvent data) =>
          unawaited(_handleTempTarget(data, context)),
      mealSuggestionResponse: (MealSuggestionResponseEvent data) {
        logI('${data.runtimeType}');
        context.emitEvent(data);
      },
      mealSummaryReminderResponse: (MealSummaryReminderResponseEvent data) =>
          data.when(
            agree: (mealId) =>
                unawaited(_markPlannedAmountAsConsumed(mealId, context)),
            dismiss: (mealId) =>
                logI('Meal summary reminder dismissed for meal $mealId'),
            empty: (mealId) =>
                logI('Meal summary reminder opened for meal $mealId'),
          ),
      finishedEatingResponse: (FinishedEatingResponseEvent data) =>
          context.emitEvent(data),
      activityFinishedResponse: (ActivityFinishedResponseEvent data) =>
          context.emitEvent(data),
      aapsCarbsRequestResponse: (AapsCarbsRequestResponseEvent data) =>
          data.when(
            agree: (episodeId) => context.emitEvent(
              AapsCarbsRequestAcknowledgedEvent(episodeId: episodeId),
            ),
            empty: (_) => context.container
                .read(taskEventRouterProvider)
                .send(const TaskOpenLowTreatmentPayload()),
          ),
    );
  }

  Future<void> _handleTempTarget(
    TempTargetResponseEvent data,
    RuntimeContext context,
  ) async {
    context.emitEvent(data);
    final requestId = data.requestId;
    try {
      final approved = data.maybeWhen(
        agree: (_, _, _, _) => true,
        dismiss: (_, _, _, _) => false,
        skip: (_, _, _, _) => false,
        orElse: () => null,
      );
      if (approved == null) return;
      if (requestId == null) {
        logI(
          'Manual temporary target reminder response: entity=${data.entityId}, type=${data.targetType}; no upload authorized',
        );
        if (approved) {
          await context.container
              .read(notificationsControllerForegroundProvider)
              .show(
                TempTargetDeliveryNotification(
                  message: lang.notificationTempTargetManualConfirmed,
                ),
              );
        }
        return;
      }
      final result = await context.container
          .read(tempTargetServiceProvider)
          .respond(
            requestId: requestId,
            targetType: data.targetType,
            entityId: data.entityId,
            approved: approved,
          );
      logI(
        'Temporary target consent response: entity=${data.entityId}, type=${data.targetType}, result=${result.name}',
      );
      final message = switch (result) {
        TempTargetSendResult.sent => null,
        TempTargetSendResult.failed => lang.notificationTempTargetFailed,
        TempTargetSendResult.expired => lang.notificationTempTargetExpired,
        TempTargetSendResult.ignored => null,
        TempTargetSendResult.deferred => null,
      };
      if (message != null) {
        await context.container
            .read(notificationsControllerForegroundProvider)
            .show(TempTargetDeliveryNotification(message: message));
      }
    } catch (error, stackTrace) {
      logE(
        'Could not handle temporary target confirmation',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // Persist responses even during service startup, before workflow inboxes exist.
  Future<void> _handleActivitySchedule(
    ActivityScheduleResponseEvent data,
    RuntimeContext context,
  ) async {
    try {
      final service = context.container.read(activityScheduleServiceProvider);
      await data.when(
        agree: (id) async {
          await service.confirm(id);
        },
        skip: service.skip,
        empty: (_) async {},
      );
    } catch (error, stackTrace) {
      logE(
        'Could not handle activity confirmation',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _markPlannedAmountAsConsumed(
    int mealId,
    RuntimeContext context,
  ) async {
    try {
      final meal = await context.container.read(
        getMealByIdProvider(mealId).future,
      );
      final status = meal?.status;
      if (!_canSummarizeFromReminder(status)) {
        logI(
          'Skipping reminder summary for meal $mealId because status is $status',
        );
        return;
      }

      await context.container
          .read(mealSnapshotControllerProvider)
          .saveConsumedSnapshot(mealId);
      await context.container.read(
        updateMealByIdProvider(mealId, 'summarized').future,
      );
      logI('Meal $mealId summarized from reminder action');
    } catch (e, st) {
      logE(
        'Could not summarize meal $mealId from reminder action',
        error: e,
        stackTrace: st,
      );
    }
  }

  bool _canSummarizeFromReminder(String? status) {
    return status == 'eaten' ||
        status == 'eaten-extra' ||
        status == 'eaten-bolused';
  }
}
