import '../../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/base/notifications_controller.dart';
import '../../../../../core/notifications/domain/events/meal_suggestion_notification.dart';
import '../../../../../features/dashboard/data/providers/meal_advisor_result_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../base/runtime_context.dart';

class BolusReminderSuggestion {
  const BolusReminderSuggestion({
    required this.carbs,
    required this.extendedCarbs,
    required this.extendedCarbsDeliveryMode,
    required this.extendedCarbsDelayMinutes,
    required this.extendedCarbsDurationMinutes,
  });

  final int carbs;
  final int extendedCarbs;
  final ExtendedCarbsDeliveryMode extendedCarbsDeliveryMode;
  final int extendedCarbsDelayMinutes;
  final int extendedCarbsDurationMinutes;
}

class BolusReminderHelper with Logging {
  static const reminderInterval = Duration(minutes: 5);

  Future<BolusReminderSuggestion> resolveMealBolusSuggestion(
    RuntimeContext runtimeContext,
    Meal meal, {
    bool consumed = false,
    MealAdvice? advice,
  }) async {
    final carbs = await resolveMealNetCarbs(
      runtimeContext,
      meal,
      consumed: consumed,
    );
    if (advice == null) {
      try {
        advice = await runtimeContext.container.read(
          getMealAdviceProvider(meal).future,
        );
      } catch (e, st) {
        logE(
          "Could not load meal advice while resolving bolus reminder",
          error: e,
          stackTrace: st,
        );
      }
    }
    final extendedCarbs = advice?.extendedCarbs;
    final scheduleSettings =
        extendedCarbs?.scheduleSettings ??
        const ExtendedCarbsScheduleSettings.defaults();

    return BolusReminderSuggestion(
      carbs: carbs,
      extendedCarbs: extendedCarbs?.grams ?? 0,
      extendedCarbsDeliveryMode: scheduleSettings.deliveryMode,
      extendedCarbsDelayMinutes: scheduleSettings.delayMinutes,
      extendedCarbsDurationMinutes: scheduleSettings.durationMinutes,
    );
  }

  Future<int> resolveMealNetCarbs(
    RuntimeContext runtimeContext,
    Meal meal, {
    bool consumed = false,
  }) async {
    final mealCarbs = meal.carbs;
    if (!consumed && mealCarbs != null && mealCarbs > 0) {
      return mealCarbs.ceil();
    }

    final summary = consumed
        ? await runtimeContext.container.read(
            mealMacronutrientsConsumedSummaryProvider(meal.id).future,
          )
        : await runtimeContext.container.read(
            mealMacronutrientsSummaryProvider(meal.id).future,
          );
    return _netCarbs(summary).ceil();
  }

  Future<int> resolveAddOnNetCarbs(
    RuntimeContext runtimeContext,
    int mealId,
  ) async {
    final plannedSummary = await runtimeContext.container.read(
      mealMacronutrientsSummaryProvider(mealId).future,
    );
    final consumedSummary = await runtimeContext.container.read(
      mealMacronutrientsConsumedSummaryProvider(mealId).future,
    );
    final addOnNetCarbs =
        _netCarbs(consumedSummary) - _netCarbs(plannedSummary);
    if (addOnNetCarbs <= 0) {
      return 0;
    }
    return addOnNetCarbs.ceil();
  }

  Future<bool> remindUntilBolusRecorded(
    RuntimeContext runtimeContext,
    NotificationsController notificationProvider,
    int mealId, {
    required int carbs,
    int extendedCarbs = 0,
    ExtendedCarbsDeliveryMode extendedCarbsDeliveryMode =
        ExtendedCarbsDeliveryMode.extendedCarbs,
    int extendedCarbsDelayMinutes = 45,
    int extendedCarbsDurationMinutes = 120,
    bool isAddOn = false,
  }) async {
    while (true) {
      logI("Cancelling previous notifications before showing bolus reminder");
      await notificationProvider.cancelAll();

      logI("User should bolus after eating, showing notification");
      await notificationProvider.show(
        MealSuggestionNotificationEvent(
          mealId: mealId,
          decision: MealDecision.bolus,
          carbs: carbs,
          extendedCarbs: extendedCarbs,
          extendedCarbsDeliveryMode: extendedCarbsDeliveryMode,
          extendedCarbsDelayMinutes: extendedCarbsDelayMinutes,
          extendedCarbsDurationMinutes: extendedCarbsDurationMinutes,
          minutes: 0,
          isAddOn: isAddOn,
        ),
      );

      logI("Notification shown, waiting for user response or calculator");
      final result = await _waitForBolusReminderResult(runtimeContext, mealId);

      if (result == null) {
        logI("Bolus reminder timed out, showing it again");
        continue;
      }

      if (result is TreatmentAvailableEvent<BolusWizard>) {
        logI(
          "Calculator response available, cancelling notifications and marking meal as bolused",
        );
        await notificationProvider.cancelAll();
        return true;
      }

      final response = result as MealSuggestionResponseEvent;
      logI("Got response from user");

      var delay = reminderInterval;
      var shouldContinue = true;

      response.when(
        agree: (int mealId) {
          logI("User agreed to bolus");
        },
        skip: (int mealId) {
          logI("User skipped meal suggestion");
          shouldContinue = false;
        },
        snooze: (int mealId, String input) {
          logI("User snoozed meal suggestion");
          delay = Duration(
            minutes: int.tryParse(input) ?? reminderInterval.inMinutes,
          );
        },
        empty: (int mealId) {
          logI("User clicked on notification probably by mistake");
        },
      );

      if (!shouldContinue) {
        await notificationProvider.cancelAll();
        return false;
      }

      final bolusResponse = await runtimeContext
          .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<BolusWizard>>(
            delay,
          );
      if (bolusResponse != null) {
        logI(
          "Calculator response available, cancelling notifications and marking meal as bolused",
        );
        await notificationProvider.cancelAll();
        return true;
      }

      logI("Calculator response missing after reminder delay, reminding again");
    }
  }

  Future<ForegroundEvent?> _waitForBolusReminderResult(
    RuntimeContext runtimeContext,
    int mealId,
  ) async {
    final responseHandle = runtimeContext
        .eventWait<MealSuggestionResponseEvent>(
          predicate: (event) => event.mealId == mealId,
        );
    final bolusHandle = runtimeContext
        .eventWait<TreatmentAvailableEvent<BolusWizard>>();
    final timeoutHandle = runtimeContext.durationWait(reminderInterval);

    return runtimeContext.any<ForegroundEvent?>([
      responseHandle.map<ForegroundEvent?>((event) => event),
      bolusHandle.map<ForegroundEvent?>((event) => event),
      timeoutHandle.map<ForegroundEvent?>((_) => null),
    ]);
  }

  double _netCarbs(MealMacroSummary? summary) {
    if (summary == null) {
      return 0;
    }
    return summary.netCarbsGrams;
  }
}
