import 'package:clock/clock.dart';

import '../../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../../common/meal_advisor/remote/meal_decision_request_creation.dart';
import '../../../../../common/monitoring/is_temporary_target_active.dart';
import '../../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../../common/nutrition/stable_macro_ceil.dart';
import '../../../../../core/domain/model/device_status.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../../core/domain/model/temporary_target.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/notifications/domain/events/meal_advice_pending_notification.dart';
import '../../../../../core/notifications/domain/events/meal_suggestion_notification.dart';
import '../../../../../core/notifications/domain/events/temp_target_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/providers/meal_advisor_result_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import '../../../../../features/meal_advisor/data/providers/check_meal_advisor_device_status_use_case_provider.dart';
import '../../../../../features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import '../../../../../features/meal_advisor/data/providers/get_meal_activity_advice_use_case_provider.dart';
import '../../../../../features/meal_advisor/data/providers/get_meal_advice_use_case_provider.dart';
import '../../../../../features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import '../../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../../event/internal/data_available_event.dart';
import '../../../../event/internal/meal_event.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../../providers/device_status_value_provider.dart';
import '../../../../runtime/wait_handle.dart';
import '../../../../synchronization/synchronization_cache_controller.dart';
import '../../../base/runtime_context.dart';
import '../helpers/planned_meal_confirmation.dart';
import '../helpers/scheduled_caregiver_meal_decision.dart';
import '../meal_monitor_context.dart';
import 'detect_finished_eating_executor.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';
import 'new_meal_check_executor.dart';
import 'wait_for_bolus_executor.dart';

enum PathDecision {
  waitUntilMealMonitorWindow,
  temporaryTargetSuggestion,
  mealAdvisor,
  abort,
}

class MonitorUntilMeal extends MealMonitorStateExecutor {
  MonitorUntilMeal();

  static const tempTargetSuggestionRetryInterval = Duration(minutes: 5);

  @override
  List<Type> get interruptableEvents => [
    MealStartedEatingEvent,
    MealEatingExtraEvent,
    MealWaitingForBolusEvent,
    MealBolusedEatingEvent,
    MealEatingThenBolus,
    MealBolusedWaitingEvent,
    MealSkippedEvent,
    NextMealEvent,
  ];

  @override
  bool shouldInterrupt(
    ForegroundEvent event,
    MealMonitorContext mealMonitorContext,
  ) {
    logI("MonitorUntilMeal shouldInterrupt ${event.runtimeType}");
    switch (event) {
      case MealSkippedEvent():
        if (mealMonitorContext.activeMeal!.id != event.mealId) {
          return false;
        }
        break;
      case NextMealEvent():
        final activeMeal = mealMonitorContext.activeMeal!;
        if (activeMeal.id == event.mealId) {
          // Reload the meal and restart waiting when its persisted time changes.
          return activeMeal.plannedAt != event.when;
        }
        break;
    }
    return true;
  }

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("WaitUntilEatingExecutor cleanup");
  }

  Future<DeviceStatus> getOrWaitForNextAvailableDeviceStatus(
    RuntimeContext context,
    Duration maxWait,
  ) {
    final deviceStatus = context.container.read(deviceStatusValueProvider);
    if (deviceStatus != null) {
      logI("device status available from beginning");
      return Future.value(deviceStatus);
    }
    return waitForNextAvailableDeviceStatus(context, maxWait);
  }

  Future<DeviceStatus> waitForNextAvailableDeviceStatus(
    RuntimeContext context,
    Duration maxWait,
  ) async {
    logI("waiting for device status for $maxWait");
    final event = await context
        .waitForEventWithTimeout<DataAvailableEvent<DeviceStatus>>(maxWait);
    return event.data;
  }

  Future<void> showTempTargetNotification(RuntimeContext context, int mealId) {
    final notificationProvider = context.container.read(
      notificationsControllerForegroundProvider,
    );
    return notificationProvider.show(
      TempTargetNotificationEvent.meal(entityId: mealId),
    );
  }

  Future<bool> showTempTargetUntilDetected(
    RuntimeContext context,
    int mealId,
    Duration maxWait, {
    void Function()? ensureActive,
  }) async {
    final deadline = clock.now().add(maxWait);

    while (clock.now().isBefore(deadline)) {
      ensureActive?.call();
      final target = context.container
          .read(synchronizationCacheControllerProvider)
          .cache
          .targetCache;
      if (isTemporaryTargetActive(target)) {
        logI("Active temporary target already available");
        return true;
      }

      logI("showing temp target suggestion notification");
      await showTempTargetNotification(context, mealId);
      ensureActive?.call();

      final remaining = deadline.difference(clock.now());
      final waitTime = remaining < tempTargetSuggestionRetryInterval
          ? remaining
          : tempTargetSuggestionRetryInterval;

      final targetEvent = await context
          .waitForEventWithTimeoutOrNull<
            TreatmentAvailableEvent<TemporaryTarget>
          >(
            waitTime,
            predicate: (event) => isTemporaryTargetActive(event.data),
          );

      if (targetEvent != null) {
        logI("Meal temp target detected");
        return true;
      }
    }

    return false;
  }

  DateTime alignToNextCgmReading(DateTime target, DateTime lastReading) {
    final processTimeBuffer = 0;
    final diffMinutes =
        target.difference(lastReading).inMinutes - processTimeBuffer;

    final remainder = diffMinutes % 5;

    final minutesToRemove = remainder;
    final minutesToAdd = 5 - minutesToRemove;

    // it is wiser to add instead of remove
    if (minutesToRemove > 3) {
      return target.add(Duration(minutes: minutesToAdd));
    } else {
      return target.subtract(Duration(minutes: minutesToRemove));
    }
  }

  PathDecision detectPathDecision(Duration timeToMeal) {
    if (timeToMeal.inMinutes > 50) {
      return PathDecision.waitUntilMealMonitorWindow;
    } else if (timeToMeal.inMinutes > 20) {
      return PathDecision.temporaryTargetSuggestion;
    } else if (timeToMeal.inMinutes > 0) {
      return PathDecision.mealAdvisor;
    }
    return PathDecision.abort;
  }

  int minutesTillNextPath(Duration timeToMeal) {
    if (timeToMeal.inMinutes > 50) {
      return timeToMeal.inMinutes - 50;
    } else if (timeToMeal.inMinutes > 20) {
      return timeToMeal.inMinutes - 20;
    } else if (timeToMeal.inMinutes > 15) {
      return timeToMeal.inMinutes - 15;
    }
    return timeToMeal.inMinutes;
  }

  Future<MealMacroSummary?> getMealSummary(
    RuntimeContext context,
    int mealId,
  ) async {
    final mealSummary = await context.container.read(
      mealMacronutrientsSummaryProvider(mealId).future,
    );
    return mealSummary;
  }

  Future<DateTime> normalizeMealTime(
    RuntimeContext runtimeContext,
    Duration maxWait,
    DateTime mealPlannedAt,
  ) async {
    final deviceStatus = await getOrWaitForNextAvailableDeviceStatus(
      runtimeContext,
      maxWait,
    );

    logI(
      "Blood sugar value: ${deviceStatus.bg} read at ${deviceStatus.date.toIso8601String()}",
    );
    return alignToNextCgmReading(mealPlannedAt, deviceStatus.date);
  }

  Future<bool> checkAdviceEligibility(
    RuntimeContext context,
    int mealId, {
    DeviceStatus? adviceStatus,
    void Function()? ensureActive,
  }) async {
    final eligibility = await context.container
        .read(checkMealAdviceEligibilityUseCaseProvider)
        .call();
    ensureActive?.call();
    final statusEligibility = context.container
        .read(checkMealAdvisorDeviceStatusUseCaseProvider)
        .call(context.container.read(deviceStatusValueProvider));
    if (eligibility == MealAdviceEligibility.available &&
        statusEligibility == MealAdviceEligibility.available &&
        (adviceStatus == null ||
            context.container
                    .read(checkMealAdvisorDeviceStatusUseCaseProvider)
                    .call(adviceStatus) ==
                MealAdviceEligibility.available)) {
      return true;
    }
    await context.container
        .read(notificationsControllerForegroundProvider)
        .show(
          MealAdvicePendingNotificationEvent(mealId: mealId, unavailable: true),
        );
    ensureActive?.call();
    return false;
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("WaitUntilEatingExecutor");

    if (mealMonitorContext.activeMeal == null) {
      logI("No meal to monitor");
      return MealMonitorStateIdle();
    }
    mealMonitorContext.publishStatus(
      runtimeContext,
      MealMonitoringPhase.planned,
    );
    final meal = mealMonitorContext.activeMeal!;
    final mealPlannedAt = meal.plannedAt!;
    final timeToMeal = mealPlannedAt.difference(clock.now());
    final requestAt = mealPlannedAt.subtract(scheduledCaregiverRequestLeadTime);
    var confirmationPending =
        meal.status == 'planned' && meal.purpose == MealPurpose.meal;
    Future<bool> confirm() async {
      if (!confirmationPending) return true;
      confirmationPending = false;
      return runtimeContext.container.read(confirmPlannedMealProvider)(
        runtimeContext,
        mealMonitorContext,
        meal,
      );
    }

    var caregiverPathHandled = false;
    bool usesCaregiver() =>
        !caregiverPathHandled &&
        meal.purpose == MealPurpose.meal &&
        usesCaregiverMealDecision(runtimeContext);
    Future<bool> requestCaregiverDecision() {
      caregiverPathHandled = true;
      return runtimeContext.container.read(
        scheduledCaregiverMealDecisionProvider,
      )(runtimeContext, mealMonitorContext, meal);
    }

    Duration limitWait(Duration wait) {
      if (!confirmationPending && !usesCaregiver()) return wait;
      final untilRequest = requestAt.difference(clock.now());
      if (untilRequest <= Duration.zero) return Duration.zero;
      return untilRequest < wait ? untilRequest : wait;
    }

    logI("Meal planned at ${mealPlannedAt.toIso8601String()}");
    logI("Time to meal ${timeToMeal.inMinutes}");

    if (timeToMeal <= scheduledCaregiverRequestLeadTime) {
      if (!await confirm() ||
          (usesCaregiver() && await requestCaregiverDecision())) {
        return MealMonitorStateIdle(phase: MealMonitoringPhase.waitingForUser);
      }
    }

    DeviceStatus? deviceStatus;

    DateTime normalizedMealTime;
    while (true) {
      try {
        normalizedMealTime = await normalizeMealTime(
          runtimeContext,
          limitWait(
            caregiverPathHandled
                ? const Duration(minutes: 7)
                : Duration(
                    minutes: mealPlannedAt.difference(clock.now()).inMinutes,
                  ),
          ),
          mealPlannedAt,
        );
        break;
      } on WaitTimeoutException catch (_) {
        if (confirmationPending && !await confirm()) {
          return MealMonitorStateIdle(
            phase: MealMonitoringPhase.waitingForUser,
          );
        }
        if (!usesCaregiver()) {
          logI("Problem normalizing meal time");
          return NewMealCheckExecutor();
        }
        if (await requestCaregiverDecision()) {
          return MealMonitorStateIdle(
            phase: MealMonitoringPhase.waitingForUser,
          );
        }
      }
    }
    mealMonitorContext.throwIfStopped(runtimeContext);

    final timeToMealNormalized = normalizedMealTime.difference(clock.now());
    logI("Normalized meal planned at ${normalizedMealTime.toIso8601String()}");
    logI("Time to meal ${timeToMealNormalized.inMinutes}");

    final mealAdvisorBuffer = 5;
    if (!caregiverPathHandled &&
        timeToMealNormalized.inMinutes < mealAdvisorBuffer) {
      logI("User probably added new meal manually using quick method");
      // The meal remains current while the user continues in the app.
      return MealMonitorStateIdle(phase: MealMonitoringPhase.waitingForUser);
    }

    var mealTempTargetDetected = false;

    while (true) {
      mealMonitorContext.throwIfStopped(runtimeContext);
      final now = clock.now();
      final timeToMeal = normalizedMealTime.difference(now);
      if (confirmationPending &&
          (!now.isBefore(requestAt) ||
              detectPathDecision(timeToMeal) == PathDecision.mealAdvisor) &&
          !await confirm()) {
        return MealMonitorStateIdle(phase: MealMonitoringPhase.waitingForUser);
      }
      if ((mealPlannedAt.difference(now) <= scheduledCaregiverRequestLeadTime ||
              detectPathDecision(timeToMeal) == PathDecision.mealAdvisor) &&
          usesCaregiver()) {
        if (await requestCaregiverDecision()) {
          return MealMonitorStateIdle(
            phase: MealMonitoringPhase.waitingForUser,
          );
        }
        continue;
      }
      final scheduledPath = detectPathDecision(timeToMeal);
      final pathDecision =
          caregiverPathHandled && scheduledPath == PathDecision.abort
          ? PathDecision.mealAdvisor
          : scheduledPath;
      if (pathDecision != PathDecision.abort) {
        mealMonitorContext.publishStatus(
          runtimeContext,
          pathDecision == PathDecision.waitUntilMealMonitorWindow
              ? MealMonitoringPhase.planned
              : MealMonitoringPhase.preparing,
        );
      }
      final maxWaitMinutes = minutesTillNextPath(timeToMeal);
      logI("Time now ${now.toIso8601String()}");
      logI("Path decision: $pathDecision");
      logI("Max wait minutes: $maxWaitMinutes");
      logI("Time to meal: ${timeToMeal.inMinutes}");

      try {
        switch (pathDecision) {
          case PathDecision.abort:
            logI("No path decision available, checking next meal");
            return NewMealCheckExecutor();
          case PathDecision.waitUntilMealMonitorWindow:
            logI(
              "Duration till meal ${timeToMeal.inMinutes} waiting for monitoring window",
            );
            await runtimeContext.waitForDuration(
              limitWait(Duration(minutes: maxWaitMinutes)),
            );
          case PathDecision.temporaryTargetSuggestion:
            logI(
              "Duration till meal ${timeToMeal.inMinutes} waiting for glucose",
            );
            final deviceStatus = await getOrWaitForNextAvailableDeviceStatus(
              runtimeContext,
              limitWait(Duration(minutes: maxWaitMinutes)),
            );
            mealMonitorContext.throwIfStopped(runtimeContext);
            logI("Blood sugar value: ${deviceStatus.bg}");
            if (deviceStatus.bg > 100 && !mealTempTargetDetected) {
              mealTempTargetDetected = await showTempTargetUntilDetected(
                runtimeContext,
                mealMonitorContext.activeMeal!.id,
                limitWait(Duration(minutes: maxWaitMinutes)),
                ensureActive: () =>
                    mealMonitorContext.throwIfStopped(runtimeContext),
              );
              continue;
            }
            if (maxWaitMinutes > 5) {
              logI("sleeping till next readaing for ${maxWaitMinutes - 5}");
              await runtimeContext.waitForDuration(
                limitWait(Duration(minutes: maxWaitMinutes - 5)),
              );
            } else {
              logI("sleeping till next path for $maxWaitMinutes");
              await runtimeContext.waitForDuration(
                limitWait(Duration(minutes: maxWaitMinutes)),
              );
            }
            break;
          case PathDecision.mealAdvisor:
            logI("building macro status ${mealMonitorContext.activeMeal!.id}");

            final mealStatus = await getMealSummary(
              runtimeContext,
              mealMonitorContext.activeMeal!.id,
            );
            mealMonitorContext.throwIfStopped(runtimeContext);

            logI("after macro status await");

            if (mealStatus == null) {
              logI("Problem gathering meal macronutrients status");
              // notify to use phone
              return NewMealCheckExecutor();
            }

            MealMonitorStateExecutor nextExecutor = MealMonitorStateIdle();
            var shouldAbort = false;
            MealAdvice? advice;
            final extendedCarbsScheduleSettings =
                runtimeContext.container
                    .read(extendedCarbsScheduleSettingsProvider)
                    .value ??
                const ExtendedCarbsScheduleSettings.defaults();

            var iterationsLeft =
                (timeToMeal.inMinutes.clamp(0, 20) / 5).floor() + 2;
            do {
              logI("iterationsLeft $iterationsLeft");
              deviceStatus = runtimeContext.container.read(
                deviceStatusValueProvider,
              );
              if (deviceStatus != null) {
                logI(
                  'deviceStatus: $iterationsLeft date ${deviceStatus.date.toIso8601String()} now ${clock.now().toIso8601String()} meal planned at ${mealPlannedAt.toIso8601String()}',
                );
                if (runtimeContext.container
                        .read(checkMealAdvisorDeviceStatusUseCaseProvider)
                        .call(deviceStatus) !=
                    MealAdviceEligibility.available) {
                  await checkAdviceEligibility(
                    runtimeContext,
                    mealMonitorContext.activeMeal!.id,
                    ensureActive: () =>
                        mealMonitorContext.throwIfStopped(runtimeContext),
                  );
                  return MealMonitorStateIdle();
                }
                final activityDoseSuggestion = await runtimeContext.container
                    .read(
                      getMealActivityAdviceUseCaseProvider,
                    )(mealAt: mealPlannedAt);
                mealMonitorContext.throwIfStopped(runtimeContext);
                advice = runtimeContext.container
                    .read(getMealAdviceUseCaseProvider)
                    .call(
                      macros: mealStatus,
                      deviceStatus: deviceStatus,
                      settings: extendedCarbsScheduleSettings,
                      activityDoseSuggestion: activityDoseSuggestion,
                    );

                final iterationsRemaining = iterationsLeft - 1;
                final minutesLeft = iterationsRemaining * 5;
                logI("iterations remaining $iterationsRemaining");
                logI("minutes left $minutesLeft");

                switch (advice.decision!) {
                  case MealDecision.bolus:
                    logE("decision is bolus, this should never happen");
                    throw Exception(
                      "decision is bolus, this should never happen",
                    );
                  case MealDecision.eatNowBolusLater:
                    logI("Meal advice: ${advice.decision.toString()}");
                    nextExecutor = DetectFinishedEatingExecutor(
                      shouldBolus: true,
                      grams: mealStatus.netCarbsGrams.ceilMacro(),
                    );
                    break;
                  case MealDecision.bolusAndEatNow:
                    logI("Meal advice: ${advice.decision.toString()}");
                    // need to store meal information for notification
                    // wait more time to return right before meal
                    nextExecutor = WaitForBolusExecutor(initialAdvice: advice);
                    break;
                  case MealDecision.bolusWaitThenEat:
                    logI("Meal advice: ${advice.decision.toString()}");
                    logI(
                      "recommended waiting for ${advice.wait!.recommendedMinutes} minutes",
                    );
                    logI("min waiting for ${advice.wait!.minMinutes} minutes");
                    logI("max waiting for ${advice.wait!.maxMinutes} minutes");
                    nextExecutor = WaitForBolusExecutor(initialAdvice: advice);
                    if (advice.wait!.recommendedMinutes >= minutesLeft) {
                      shouldAbort = true;
                    }
                    break;
                }
              }
              if (shouldAbort || iterationsLeft == 1) break;

              try {
                deviceStatus = await waitForNextAvailableDeviceStatus(
                  runtimeContext,
                  const Duration(minutes: 7),
                );
              } on WaitTimeoutException catch (_) {
                logI("No device status available for 7 minutes");
                if (advice != null) {
                  logI("Using last available meal advice after device timeout");
                  break;
                }
                deviceStatus = null;
              }
            } while (--iterationsLeft > 0);

            logI("Ended loop");

            // A timeout may retain the last advice and its device status.
            // Both must be available before showing a suggestion.
            if (advice == null || deviceStatus == null) {
              logI("No advice available, checking next meal");
              return NewMealCheckExecutor();
            }
            if (!await checkAdviceEligibility(
              runtimeContext,
              mealMonitorContext.activeMeal!.id,
              adviceStatus: deviceStatus,
              ensureActive: () =>
                  mealMonitorContext.throwIfStopped(runtimeContext),
            )) {
              return MealMonitorStateIdle();
            }
            final mealAdvice = advice;
            final adviceDeviceStatus = deviceStatus;

            // notify user about suggestion (if any)
            final notificationProvider = runtimeContext.container.read(
              notificationsControllerForegroundProvider,
            );
            await notificationProvider.show(
              MealSuggestionNotificationEvent(
                mealId: mealMonitorContext.activeMeal!.id,
                minutes: mealAdvice.wait?.recommendedMinutes ?? 0,
                activityDoseSuggestion: mealAdvice.activityDoseSuggestion,
                decision: mealAdvice.decision!,
                isPlannedAdvice: meal.status == 'planned',
                carbs: mealStatus.netCarbsGrams.ceilMacro(),
                extendedCarbs:
                    mealAdvice.decision == MealDecision.eatNowBolusLater
                    ? 0
                    : mealAdvice.extendedCarbs.grams,
                extendedCarbsDeliveryMode:
                    mealAdvice.extendedCarbs.scheduleSettings.deliveryMode,
                extendedCarbsDelayMinutes:
                    mealAdvice.extendedCarbs.scheduleSettings.delayMinutes,
                extendedCarbsDurationMinutes:
                    mealAdvice.extendedCarbs.scheduleSettings.durationMinutes,
              ),
            );
            mealMonitorContext.throwIfStopped(runtimeContext);

            logI("Waiting for user response");
            final response = await runtimeContext
                .waitForEvent<MealSuggestionResponseEvent>(
                  predicate: (event) =>
                      event.mealId == mealMonitorContext.activeMeal!.id &&
                      event.plannedAtMs == null,
                );
            // if no response but device status came, recalculate
            var retry = false;
            logI("Received response from user");
            await response.when(
              agree: (_, _) async {
                if (!await checkAdviceEligibility(
                  runtimeContext,
                  mealMonitorContext.activeMeal!.id,
                  adviceStatus: adviceDeviceStatus,
                  ensureActive: () =>
                      mealMonitorContext.throwIfStopped(runtimeContext),
                )) {
                  nextExecutor = MealMonitorStateIdle();
                  return;
                }
                final decisionStatus = mealAdvice.decision!.acceptedStatus;
                logI("User agreed meal, decision: $decisionStatus");
                // An old offer may be answered after another decision was
                // made (caregiver, manual): it must not change that meal.
                if (await _decisionAlreadyMade(
                  runtimeContext,
                  mealMonitorContext.activeMeal!.id,
                )) {
                  logI("Ignoring a stale meal advisor answer");
                  nextExecutor = NewMealCheckExecutor();
                  return;
                }
                mealMonitorContext.throwIfStopped(runtimeContext);
                // Saving the advice first fails on an existing decision
                // before the meal status could change.
                await runtimeContext.container.read(
                  insertAdviceProvider(
                    mealMonitorContext.activeMeal!,
                    mealAdvice,
                  ).future,
                );
                mealMonitorContext.throwIfStopped(runtimeContext);
                await runtimeContext.container.read(
                  updateMealProvider(
                    mealMonitorContext.activeMeal!,
                    decisionStatus,
                  ).future,
                );
                mealMonitorContext.throwIfStopped(runtimeContext);
                mealMonitorContext.activeMeal = mealMonitorContext.activeMeal!
                    .copyWith(status: decisionStatus, updatedAt: clock.now());
              },
              skip: (_, _) async {
                if (meal.status == 'planned') {
                  await disablePlannedMealMonitoring(
                    runtimeContext,
                    meal,
                    manual: true,
                  );
                  nextExecutor = MealMonitorStateIdle(
                    phase: MealMonitoringPhase.waitingForUser,
                  );
                  return;
                }
                logI("User dismissed meal, clicked on notification");
                await runtimeContext.container.read(
                  updateMealProvider(
                    mealMonitorContext.activeMeal!,
                    'skipped',
                  ).future,
                );
                mealMonitorContext.throwIfStopped(runtimeContext);
                nextExecutor = MealMonitorStateIdle();
              },
              snooze: (_, _, input) {
                logI("Snooze input: $input");
                final minutes = int.parse(input);
                normalizedMealTime = alignToNextCgmReading(
                  normalizedMealTime.add(Duration(minutes: minutes)),
                  deviceStatus!.date,
                );
                retry = true;
              },
              empty: (_, _) {
                logI(
                  "No action from user, clicked on notification he will continue in-app",
                );
                nextExecutor = MealMonitorStateIdle(
                  phase: MealMonitoringPhase.waitingForUser,
                );
              },
            );

            if (retry) {
              logI(
                "Retrying with new meal planned at ${normalizedMealTime.toIso8601String()}",
              );
              continue;
            }

            return nextExecutor;
        }
      } on WaitTimeoutException catch (_) {
        logI("Problem reading data, moving to next step");
        continue;
      }
    }
  }
}

Future<bool> _decisionAlreadyMade(RuntimeContext runtime, int mealId) async {
  if (!runtime.container.exists(databaseProvider)) return false;
  final db = runtime.container.read(databaseProvider);
  if (!db.hasOpened) return false;
  final current = await db.mealDao.getMealById(mealId);
  if (current == null) return false;
  return current.status != 'planned' ||
      await db.mealAdvisorResultDao.getMealAdvisorResult(mealId) != null;
}
