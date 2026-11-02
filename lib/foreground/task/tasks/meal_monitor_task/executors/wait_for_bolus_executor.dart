import 'package:clock/clock.dart';

import '../../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../../common/meal/meal_bolus_timing.dart';
import '../../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../../common/notifications/meal_notification_cancellation.dart';
import '../../../../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/drift/providers/database_provider.dart';
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
import '../helpers/meal_add_on_bolus_waiter.dart';
import '../helpers/record_meal_wizard_link.dart';
import '../helpers/wait_for_meal_bolus_delivery.dart';
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
  final int? confirmedCarbs;

  WaitForBolusExecutor({
    this.remindImmediately = true,
    DateTime? waitingSince,
    this.initialAdvice,
    this.confirmedCarbs,
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
    mealMonitorContext.publishStatus(
      runtimeContext,
      MealMonitoringPhase.waitingForBolus,
    );
    final meal = mealMonitorContext.activeMeal!;
    final status = meal.status;
    if (status == 'skipped' ||
        status == 'summarized' ||
        status == 'interrupted') {
      logI("Meal no longer waits for bolus, checking next meal");
      return NewMealCheckExecutor();
    }
    final persisted = await const MealAddOnBolusWaiter()(
      runtimeContext,
      mealMonitorContext,
      remindImmediately: remindImmediately,
    );
    mealMonitorContext.throwIfStopped(runtimeContext);
    if (persisted != null) {
      if (!persisted) {
        await runtimeContext.container.read(
          updateMealProvider(meal, 'skipped').future,
        );
        await runtimeContext.container
            .read(notificationsControllerForegroundProvider)
            .cancelMealNotifications(meal.id, includeTargetConsent: true);
        return NewMealCheckExecutor();
      }
      // A later add-on can confirm this status again. Record this occurrence
      // explicitly instead of reusing the earlier status or a cached write.
      final recorded = await runtimeContext.container
          .read(databaseProvider)
          .mealDao
          .tryUpdateMealStatus(
            meal.id,
            'eaten-bolused',
            occurredAt: clock.now(),
          );
      mealMonitorContext.throwIfStopped(runtimeContext);
      if (!recorded) return NewMealCheckExecutor();
      return FinalizeMealExecutor();
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
    mealMonitorContext.throwIfStopped(runtimeContext);
    final decision = advice?.decision ?? MealDecision.eatNowBolusLater;

    if (decision != MealDecision.eatNowBolusLater &&
        decision != MealDecision.bolusAndEatNow &&
        decision != MealDecision.bolusWaitThenEat) {
      logI("No bolus advice available, checking next meal");
      return NewMealCheckExecutor();
    }

    TreatmentAvailableEvent<BolusWizard>? calculatorResponse;
    var latestBolus = runtimeContext.container.read(latestBolusWizardProvider);
    if (latestBolus == null &&
        runtimeContext.container.exists(databaseProvider)) {
      final db = runtimeContext.container.read(databaseProvider);
      if (db.hasOpened) {
        final reference = meal.updatedAt ?? waitingSince;
        final saved = await db.localMirrorDao.getBolusWizardsBetween(
          reference.subtract(const Duration(minutes: 5)),
          clock.now(),
        );
        for (final row in saved.reversed) {
          final candidate = row.toDomain();
          if (!await mealBolusWizardAlreadyAssigned(db, candidate)) {
            latestBolus = candidate;
            break;
          }
        }
      }
    }
    if (latestBolus != null &&
        runtimeContext.container.exists(databaseProvider)) {
      final db = runtimeContext.container.read(databaseProvider);
      if (db.hasOpened &&
          await mealBolusWizardAlreadyAssigned(db, latestBolus)) {
        consumeBolusWizard(runtimeContext.container, latestBolus);
        latestBolus = null;
      }
    }
    if (latestBolus != null &&
        isMealBolusRecent(
          bolusAt: latestBolus.createdAt,
          referenceTime: meal.updatedAt ?? waitingSince,
        )) {
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
        confirmedCarbs == null ? meal : meal.copyWith(carbs: confirmedCarbs),
        consumed: decision == MealDecision.eatNowBolusLater,
        advice: advice,
      );
      mealMonitorContext.throwIfStopped(runtimeContext);
      final bolusRecorded = await _bolusReminderHelper.remindUntilBolusRecorded(
        runtimeContext,
        notificationProvider,
        meal.id,
        onBolusRecorded: (wizard) {
          calculatorResponse = TreatmentAvailableEvent<BolusWizard>(wizard);
        },
        carbs: suggestion.carbs,
        extendedCarbs: suggestion.extendedCarbs,
        extendedCarbsDeliveryMode: suggestion.extendedCarbsDeliveryMode,
        extendedCarbsDelayMinutes: suggestion.extendedCarbsDelayMinutes,
        extendedCarbsDurationMinutes: suggestion.extendedCarbsDurationMinutes,
        ensureActive: () => mealMonitorContext.throwIfStopped(runtimeContext),
      );
      mealMonitorContext.throwIfStopped(runtimeContext);
      if (!bolusRecorded) {
        await runtimeContext.container.read(
          updateMealProvider(meal, 'skipped').future,
        );
        await notificationProvider.cancelMealNotifications(
          meal.id,
          includeTargetConsent: true,
        );
        return NewMealCheckExecutor();
      }
    } else {
      logI("Calculator response available, cancelling meal notifications");
      await notificationProvider.cancelMealNotifications(meal.id);
    }

    mealMonitorContext.throwIfStopped(runtimeContext);
    final pendingCalculator = calculatorResponse;
    if (pendingCalculator != null) {
      final confirmed = await const WaitForMealBolusDelivery()(
        runtimeContext,
        mealMonitorContext,
        pendingCalculator.data,
      );
      calculatorResponse = TreatmentAvailableEvent<BolusWizard>(
        confirmed.wizard,
      );
      mealMonitorContext.throwIfStopped(runtimeContext);
    }
    final nextStatus = decision == MealDecision.eatNowBolusLater
        ? 'eaten-bolused'
        : decision.status;
    await runtimeContext.container.read(
      updateMealProvider(meal, nextStatus).future,
    );
    mealMonitorContext.throwIfStopped(runtimeContext);
    final recordedBolus = calculatorResponse;
    if (recordedBolus != null) {
      await const RecordMealWizardLink()(
        runtimeContext,
        recordedBolus.data,
        meal.id,
      );
      mealMonitorContext.throwIfStopped(runtimeContext);
      consumeBolusWizard(runtimeContext.container, recordedBolus.data);
    }

    if (decision == MealDecision.eatNowBolusLater) {
      return FinalizeMealExecutor();
    }

    if (decision == MealDecision.bolusWaitThenEat) {
      return BolusThenWaitExecutor(
        recommendedMinutes: advice?.wait?.recommendedMinutes,
        isManual: advice?.source == 'manual',
      );
    }

    return DetectFinishedEatingExecutor(shouldBolus: false);
  }
}
