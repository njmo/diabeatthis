import 'package:clock/clock.dart';

import '../../../../../common/meal/calculator/meal_calculator_request_controller_provider.dart';
import '../../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../../common/meal/meal_bolus_timing.dart';
import '../../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../../common/notifications/meal_notification_cancellation.dart';
import '../../../../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/providers/meal_advisor_result_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/meals/common/models/meal_wizard_relation_type.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../../providers/latest_bolus_wizard_provider.dart';
import '../../../base/runtime_context.dart';
import '../helpers/bolus_reminder_helper.dart';
import '../helpers/meal_add_on_bolus_waiter.dart';
import '../helpers/meal_completion_requirements.dart';
import '../helpers/record_meal_wizard_link.dart';
import '../meal_monitor_context.dart';
import 'bolus_then_wait_executor.dart';
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
    final meal = mealMonitorContext.activeMeal!;
    if (runtimeContext.container.exists(databaseProvider)) {
      final db = runtimeContext.container.read(databaseProvider);
      if (db.hasOpened) {
        final current = await db.mealDao.getMealById(meal.id);
        mealMonitorContext.throwIfStopped(runtimeContext);
        if (const {
          'eaten-bolused',
          'bolused-eating',
          'bolused-waiting',
        }.contains(current?.status)) {
          return NewMealCheckExecutor();
        }
      }
    }
    mealMonitorContext.publishStatus(
      runtimeContext,
      MealMonitoringPhase.waitingForBolus,
    );
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

    bool acceptsRecentWizard(BolusWizard wizard) => isMealBolusRecent(
      bolusAt: wizard.createdAt,
      referenceTime: meal.updatedAt ?? waitingSince,
    );

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
    if (latestBolus != null && acceptsRecentWizard(latestBolus)) {
      logI("Recent calculator response already available");
      calculatorResponse = TreatmentAvailableEvent<BolusWizard>(latestBolus);
    }
    final hasCalculatorTracker =
        runtimeContext.container.exists(databaseProvider) ||
        runtimeContext.container.exists(
          mealCalculatorRequestControllerProvider,
        );
    BolusReminderSuggestion? suggestion;
    if (hasCalculatorTracker) {
      suggestion = await _bolusReminderHelper.resolveMealBolusSuggestion(
        runtimeContext,
        confirmedCarbs == null ? meal : meal.copyWith(carbs: confirmedCarbs),
        consumed: decision == MealDecision.eatNowBolusLater,
        advice: advice,
      );
      mealMonitorContext.throwIfStopped(runtimeContext);
      await runtimeContext.container
          .read(mealCalculatorRequestControllerProvider)
          .register(
            AapsBolusSuggestionNotificationEvent(
              mealId: meal.id,
              carbs: suggestion.carbs,
              extendedCarbs: suggestion.extendedCarbs,
              extendedCarbsDeliveryMode: suggestion.extendedCarbsDeliveryMode,
              extendedCarbsDelayMinutes: suggestion.extendedCarbsDelayMinutes,
              extendedCarbsDurationMinutes:
                  suggestion.extendedCarbsDurationMinutes,
            ),
            openedAt:
                calculatorResponse?.data.createdAt ??
                meal.updatedAt ??
                waitingSince,
            refreshRequirements: true,
          );
      mealMonitorContext.throwIfStopped(runtimeContext);
    }
    if (calculatorResponse == null && !remindImmediately) {
      Log.diagnostic('AapsTreatmentTrace', 'monitorWaitingForCalculator');
      logI("Waiting for calculator use before moving to next step");
      calculatorResponse = await runtimeContext
          .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<BolusWizard>>(
            Duration(minutes: 20),
            predicate: (event) => acceptsRecentWizard(event.data),
          );
    }

    if (calculatorResponse == null) {
      Log.diagnostic(
        'AapsTreatmentTrace',
        'monitorCalculatorMissing reminder=true',
      );
      logI("Calculator response missing, showing bolus reminder");
      suggestion ??= await _bolusReminderHelper.resolveMealBolusSuggestion(
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
        acceptsBolus: acceptsRecentWizard,
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
      Log.diagnostic(
        'AapsTreatmentTrace',
        'monitorCalculator at='
            '${pendingCalculator.data.createdAt.millisecondsSinceEpoch}',
      );
    }
    final nextStatus = decision == MealDecision.eatNowBolusLater
        ? 'eaten-bolused'
        : 'bolused-waiting';
    var confirmed = const <BolusWizard>[];
    while (true) {
      if (pendingCalculator != null) {
        confirmed = await waitForMealCarbDeliveries(
          runtimeContext,
          mealMonitorContext,
          pendingCalculator.data,
          previouslyAccepted: confirmed,
        );
      }
      mealMonitorContext.throwIfStopped(runtimeContext);
      if (decision != MealDecision.bolusWaitThenEat) {
        await waitForMealCompletionRequirements(
          runtimeContext,
          mealMonitorContext,
          hasPendingRequirements: () =>
              mealHasPendingExtendedCarbs(runtimeContext, meal.id),
        );
      }
      final committed = await commitMealBolusDeliveries(
        runtimeContext,
        mealMonitorContext,
        confirmed,
        nextStatus,
      );
      if (committed == false) {
        Log.diagnostic('AapsTreatmentTrace', 'monitorCommitDeferred');
        if (runtimeContext.container.exists(databaseProvider)) {
          final current = await runtimeContext.container
              .read(databaseProvider)
              .mealDao
              .getMealById(meal.id);
          if (current?.status != 'waiting-for-bolus') {
            return NewMealCheckExecutor();
          }
        }
        await runtimeContext.waitForDuration(mealRequirementRefreshInterval);
        continue;
      }
      if (committed == null) {
        for (final (index, wizard) in confirmed.indexed) {
          await const RecordMealWizardLink()(
            runtimeContext,
            wizard,
            meal.id,
            type: index == 0
                ? MealWizardRelationType.initial
                : MealWizardRelationType.continuation,
          );
          mealMonitorContext.throwIfStopped(runtimeContext);
        }
        await runtimeContext.container.read(
          updateMealProvider(meal, nextStatus).future,
        );
      }
      Log.diagnostic(
        'AapsTreatmentTrace',
        'monitorAdvanced status=$nextStatus calculators=${confirmed.length}',
      );
      break;
    }
    for (final wizard in confirmed) {
      consumeBolusWizard(runtimeContext.container, wizard);
    }

    mealMonitorContext.throwIfStopped(runtimeContext);

    if (decision == MealDecision.eatNowBolusLater) {
      return FinalizeMealExecutor();
    }

    final immediate = decision == MealDecision.bolusAndEatNow;
    return BolusThenWaitExecutor(
      recommendedMinutes: immediate ? 0 : advice?.wait?.recommendedMinutes,
      isManual: advice?.source == 'manual',
      confirmImmediately: immediate,
      alreadyWaiting: true,
    );
  }
}
