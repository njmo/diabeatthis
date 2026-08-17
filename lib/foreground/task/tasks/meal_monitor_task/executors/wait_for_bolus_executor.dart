import 'package:clock/clock.dart';

import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/providers/meal_advisor_result_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../../providers/latest_bolus_wizard_provider.dart';
import '../../../base/runtime_context.dart';
import '../helpers/bolus_reminder_helper.dart';
import '../meal_monitor_context.dart';
import 'bolus_then_wait_executor.dart';
import 'detect_finished_eating_executor.dart';
import 'finalize_meal_executor.dart';
import 'meal_monitor_state_executor.dart';
import 'new_meal_check_executor.dart';

class WaitForBolusExecutor extends MealMonitorStateExecutor with Logging {
  final BolusReminderHelper _bolusReminderHelper = BolusReminderHelper();
  final bool remindImmediately;
  final DateTime waitingSince;
  final MealAdvice? initialAdvice;

  WaitForBolusExecutor({
    this.remindImmediately = true,
    DateTime? waitingSince,
    this.initialAdvice,
  }) : waitingSince = waitingSince ?? clock.now();

  @override
  List<Type> get interruptableEvents => [MealSkippedEvent];

  @override
  bool shouldInterrupt(
    ForegroundEvent event,
    MealMonitorContext mealMonitorContext,
  ) {
    logI("WaitForBolusExecutor shouldInterrupt ${event.runtimeType}");
    if (event is MealStatusChangedEvent) {
      return event.mealId == mealMonitorContext.activeMeal!.id;
    }
    return true;
  }

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("WaitForBolusExecutor cleanup");
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    final meal = mealMonitorContext.activeMeal!;
    final status = meal.status;
    if (status == 'skipped' || status == 'summarized') {
      logI("Meal no longer waits for bolus, checking next meal");
      return NewMealCheckExecutor();
    }
    final notificationProvider = runtimeContext.container.read(
      notificationsControllerForegroundProvider,
    );
    var advice = initialAdvice;
    if (advice == null) {
      try {
        advice = await runtimeContext.container.read(
          getMealAdviceProvider(meal).future,
        );
      } catch (e, st) {
        logE(
          "Could not load meal advice while waiting for bolus",
          error: e,
          stackTrace: st,
        );
      }
    }
    final decision = advice?.decision ?? MealDecision.eatNowBolusLater;

    if (decision != MealDecision.eatNowBolusLater &&
        decision != MealDecision.bolusAndEatNow &&
        decision != MealDecision.bolusWaitThenEat) {
      logI("No bolus advice available, checking next meal");
      return NewMealCheckExecutor();
    }

    TreatmentAvailableEvent<BolusWizard>? calculatorResponse;
    final latestBolus = runtimeContext.container.read(
      latestBolusWizardProvider,
    );
    final bolusLookupSince = meal.updatedAt ?? waitingSince;
    if (latestBolus != null &&
        !latestBolus.createdAt.isBefore(bolusLookupSince)) {
      logI("Recent calculator response already available");
      calculatorResponse = TreatmentAvailableEvent<BolusWizard>(latestBolus);
    }
    if (calculatorResponse == null && !remindImmediately) {
      logI("Waiting for calculator use before moving to next step");
      calculatorResponse = await runtimeContext
          .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<BolusWizard>>(
            Duration(minutes: 20),
          );
    }

    if (calculatorResponse == null) {
      logI("Calculator response missing, showing bolus reminder");
      final suggestion = await _bolusReminderHelper.resolveMealBolusSuggestion(
        runtimeContext,
        meal,
        advice: advice,
      );
      final bolusRecorded = await _bolusReminderHelper.remindUntilBolusRecorded(
        runtimeContext,
        notificationProvider,
        meal.id,
        carbs: suggestion.carbs,
        extendedCarbs: suggestion.extendedCarbs,
        extendedCarbsDeliveryMode: suggestion.extendedCarbsDeliveryMode,
        extendedCarbsDelayMinutes: suggestion.extendedCarbsDelayMinutes,
        extendedCarbsDurationMinutes: suggestion.extendedCarbsDurationMinutes,
      );
      if (!bolusRecorded) {
        await runtimeContext.container.read(
          updateMealProvider(meal, 'skipped').future,
        );
        return NewMealCheckExecutor();
      }
    } else {
      logI("Calculator response available, cancelling meal notifications");
      await notificationProvider.cancelAll();
    }

    final nextStatus = decision == MealDecision.eatNowBolusLater
        ? 'eaten-bolused'
        : decision.status;
    await runtimeContext.container.read(
      updateMealProvider(meal, nextStatus).future,
    );

    if (decision == MealDecision.eatNowBolusLater) {
      return FinalizeMealExecutor();
    }

    if (decision == MealDecision.bolusWaitThenEat) {
      return BolusThenWaitExecutor(
        recommendedMinutes: advice?.wait?.recommendedMinutes,
      );
    }

    return DetectFinishedEatingExecutor(shouldBolus: false);
  }
}
