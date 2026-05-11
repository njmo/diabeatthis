import 'dart:async';

import '../../../../common/events/data/notification/finished_eating_response_event.dart';
import '../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../common/events/data/notification/meal_summary_reminder_response_event.dart';
import '../../../../common/events/data/notification/temp_target_response_event.dart';
import '../../../../core/logger/logger.dart';
import '../../../../features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import '../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../task/base/runtime_context.dart';
import 'notification_response_event.dart';

class NotificationResponseEventHandler with Logging {
  NotificationResponseEventHandler();

  void handle(NotificationResponseEvent event, RuntimeContext context) {
    event.when(
      eatNowResponse: (data) => context.emitEvent(data),
      tempTargetResponse: (TempTargetResponseEvent data) =>
          context.emitEvent(data),
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
    );
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
