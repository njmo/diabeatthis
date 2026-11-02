import 'dart:async';

import 'package:clock/clock.dart';

import '../../../../common/events/data/notification/aaps_carbs_request_response_event.dart';
import '../../../../common/events/data/notification/activity_finished_response_event.dart';
import '../../../../common/events/data/notification/activity_schedule_response_event.dart';
import '../../../../common/events/data/notification/finished_eating_response_event.dart';
import '../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../common/events/data/notification/meal_summary_reminder_response_event.dart';
import '../../../../common/events/data/notification/temp_target_response_event.dart';
import '../../../../common/events/data/task/task_open_low_treatment_payload.dart';
import '../../../../common/events/data/task/task_open_meal_completion_payload.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_completion_timing.dart';
import '../../../../common/meal/pending_meal_completion_requests.dart';
import '../../../../core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/providers/database_provider.dart';
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
          unawaited(handleFinishedEatingResponse(data, context)),
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

  Future<void> handleFinishedEatingResponse(
    FinishedEatingResponseEvent data,
    RuntimeContext context,
  ) async {
    final agreed = data.maybeWhen(agree: (_) => true, orElse: () => false);
    if (!agreed) {
      context.emitEvent(data);
      return;
    }
    try {
      final db = context.container.read(databaseProvider);
      final meal = await db.mealDao.getMealById(data.mealId);
      if (meal == null ||
          (!mealStatusesStartingEating.contains(meal.status) &&
              meal.status != 'eating-extra')) {
        await _acknowledgeMealCompletion(data.mealId, context);
        return;
      }
      final history = await (db.select(
        db.mealStatusHistory,
      )..where((row) => row.mealId.equals(data.mealId))).get();
      final timing = MealCompletionTiming.fromHistory(
        history.map(
          (entry) => (
            status: entry.status,
            at: DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
          ),
        ),
        currentStatus: meal.status,
      );
      if (timing.needsTimeConfirmation(clock.now())) {
        await _requestMealCompletion(data.mealId, context);
        return;
      }
      // A live service may still be restoring this meal's event waiter.
      // Keep the intent until recovery observes a persisted completion.
      context.emitEvent(data);
    } catch (error, stackTrace) {
      logE(
        'Could not confirm eating time',
        error: error,
        stackTrace: stackTrace,
      );
      await _requestMealCompletion(data.mealId, context);
    }
  }

  Future<void> _requestMealCompletion(
    int mealId,
    RuntimeContext context,
  ) async {
    try {
      await context.container
          .read(pendingMealCompletionRequestsProvider)
          .request(mealId);
    } catch (error, stackTrace) {
      logE(
        'Could not persist meal completion request',
        error: error,
        stackTrace: stackTrace,
      );
    }
    context.container
        .read(taskEventRouterProvider)
        .send(TaskOpenMealCompletionPayload(mealId: mealId));
  }

  Future<void> _acknowledgeMealCompletion(
    int mealId,
    RuntimeContext context,
  ) async {
    try {
      await context.container
          .read(pendingMealCompletionRequestsProvider)
          .acknowledge(mealId);
    } catch (error, stackTrace) {
      logE(
        'Could not acknowledge meal completion request',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
