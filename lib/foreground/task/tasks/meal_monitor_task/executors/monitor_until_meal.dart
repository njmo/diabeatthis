import 'dart:math';

import '../../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../../core/domain/model/device_status.dart';
import '../../../../../core/drift/dao/ingredient_dao.dart';
import '../../../../../core/notifications/domain/events/meal_suggestion_notification.dart';
import '../../../../../core/notifications/domain/events/temp_target_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/dashboard/data/utils/nightscout_utils.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../../event/internal/data_available_event.dart';
import '../../../../event/internal/meal_event.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../../providers/device_status_value_provider.dart';
import '../../../../runtime/wait_handle.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'detect_finished_eating_executor.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';
import 'bolus_then_wait_executor.dart';

enum PathDecision {
  waitUntilMealMonitorWindow,
  temporaryTargetSuggestion,
  mealAdvisor,
  abort,
}

class MonitorUntilMeal extends MealMonitorStateExecutor {
  MonitorUntilMeal();

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
        if (mealMonitorContext.activeMeal!.id == event.mealId) {
          return false;
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
    int maxMinutes,
  ) {
    final deviceStatus = context.container.read(deviceStatusValueProvider);
    if (deviceStatus != null) {
      logI("device status available from beginning");
      return Future.value(deviceStatus);
    }
    return waitForNextAvailableDeviceStatus(context, maxMinutes);
  }

  Future<DeviceStatus> waitForNextAvailableDeviceStatus(
    RuntimeContext context,
    int maxMinutes,
  ) async {
    logI("waiting for device status");
    final event = await context
        .waitForEventWithTimeout<DataAvailableEvent<DeviceStatus>>(
          Duration(minutes: maxMinutes),
        );
    return event.data;
  }

  void showTempTargetNotification(RuntimeContext context) {
    final notificationProvider = context.container.read(
      notificationsControllerForegroundProvider,
    );
    notificationProvider.show(
      TempTargetNotificationEvent(tempTargetString: 'Meal'),
    );
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

  Future<DateTime> normalizeMealTime(
    RuntimeContext runtimeContext,
    Duration timeToMeal,
    DateTime mealPlannedAt,
  ) async {
    final deviceStatus = await getOrWaitForNextAvailableDeviceStatus(
      runtimeContext,
      timeToMeal.inMinutes,
    );

    logI(
      "Blood sugar value: ${deviceStatus.bg} read at ${deviceStatus.date.toIso8601String()}",
    );
    return alignToNextCgmReading(mealPlannedAt, deviceStatus.date);
  }

  MealAdvice getMealAdvice(MealSummary mealStatus, DeviceStatus deviceStatus) {
    final carbs = mealStatus.carbsG;
    final fatGrams = mealStatus.fatGrams;
    final fiberGrams = mealStatus.fiberGrams;
    final proteinGrams = mealStatus.proteinGrams;
    return MealAdvisor().getMealAdvice(
      bg: deviceStatus.bg,
      iob: deviceStatus.iob,
      cob: deviceStatus.cob,
      trend: (parseTick(deviceStatus.tick) / 5).round(),
      mealCarbs: carbs,
      fatGrams: fatGrams,
      proteinGrams: proteinGrams,
      fiberGrams: fiberGrams,
    );
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
    final mealPlannedAt = mealMonitorContext.activeMeal!.plannedAt!;
    final timeToMeal = mealPlannedAt.difference(DateTime.now());
    logI("Meal planned at ${mealPlannedAt.toIso8601String()}");
    logI("Time to meal ${timeToMeal.inMinutes}");

    DeviceStatus? deviceStatus;

    DateTime normalizedMealTime;
    try {
      normalizedMealTime = await normalizeMealTime(
        runtimeContext,
        timeToMeal,
        mealPlannedAt,
      );
    } catch (e) {
      logI("Problem normalizing meal time");
      return MealMonitorStateIdle();
    }

    final timeToMealNormalized = normalizedMealTime.difference(DateTime.now());
    logI("Normalized meal planned at ${normalizedMealTime.toIso8601String()}");
    logI("Time to meal ${timeToMealNormalized.inMinutes}");

    final mealAdvisorBuffer = 5;
    if (timeToMealNormalized.inMinutes < mealAdvisorBuffer) {
      logI("User probably added new meal manually using quick method");
      // will wait for user further actions.
      return MealMonitorStateIdle();
    }

    while (true) {
      final now = DateTime.now();
      final timeToMeal = normalizedMealTime.difference(now);
      final pathDecision = detectPathDecision(timeToMeal);
      final maxWaitMinutes = minutesTillNextPath(timeToMeal);
      logI("Time now ${now.toIso8601String()}");
      logI("Path decision: $pathDecision");
      logI("Max wait minutes: $maxWaitMinutes");
      logI("Time to meal: ${timeToMeal.inMinutes}");

      try {
        switch (pathDecision) {
          case PathDecision.abort:
            logI("No path decision available going to idle state");
            return MealMonitorStateIdle();
          case PathDecision.waitUntilMealMonitorWindow:
            logI(
              "Duration till meal ${timeToMeal.inMinutes} waiting for monitoring window",
            );
            await runtimeContext.waitForDuration(
              Duration(minutes: maxWaitMinutes),
            );
          case PathDecision.temporaryTargetSuggestion:
            logI(
              "Duration till meal ${timeToMeal.inMinutes} waiting for glucose",
            );
            final deviceStatus = await getOrWaitForNextAvailableDeviceStatus(
              runtimeContext,
              maxWaitMinutes,
            );
            logI("Blood sugar value: ${deviceStatus.bg}");
            if (deviceStatus.bg > 100) {
              logI("showing temp target suggestion notification");
              showTempTargetNotification(runtimeContext);

              logI("showing notification done sleeping till next path");
              await runtimeContext.waitForDuration(
                Duration(minutes: maxWaitMinutes),
              );
            }
            break;
          case PathDecision.mealAdvisor:
            logI("building macro status");
            // build meal macronutrient status
            final mealStatus = await runtimeContext.container.read(
              mealMacronutrientsSummaryProvider(
                mealMonitorContext.activeMeal!.id,
              ).future,
            );

            if (mealStatus == null) {
              logI("Problem gathering meal macronutrients status");
              // notify to use phone
              return MealMonitorStateIdle();
            }

            MealMonitorStateExecutor nextExecutor = MealMonitorStateIdle();
            var shouldAbort = false;
            MealAdvice? advice;

            var iterationsLeft = (timeToMeal.inMinutes / 5).floor() + 2;
            do {
              logI("iterationsLeft $iterationsLeft");
              deviceStatus = runtimeContext.container.read(
                deviceStatusValueProvider,
              );
              if (deviceStatus != null) {
                logI(
                  'deviceStatus: $iterationsLeft date ${deviceStatus.date.toIso8601String()} now ${DateTime.now().toIso8601String()} meal planned at ${mealPlannedAt.toIso8601String()}',
                );
                advice = getMealAdvice(mealStatus, deviceStatus);

                final iterationsRemaining = iterationsLeft - 1;
                final minutesLeft = iterationsRemaining * 5;
                logI("iterations remaining $iterationsRemaining");
                logI("minutes left $minutesLeft");

                switch (advice.decision!) {
                  case MealDecision.eatNowBolusLater:
                    logI("Meal advice: ${advice.decision.toString()}");
                    nextExecutor = DetectFinishedEatingExecutor(
                      shouldBolus: true,
                      grams: mealStatus.carbsG.round(),
                    );
                    break;
                  case MealDecision.bolusAndEatNow:
                    logI("Meal advice: ${advice.decision.toString()}");
                    // need to store meal information for notification
                    // wait more time to return right before meal
                    nextExecutor = DetectFinishedEatingExecutor(
                      shouldBolus: false,
                    );
                    break;
                  case MealDecision.bolusWaitThenEat:
                    logI("Meal advice: ${advice.decision.toString()}");
                    logI(
                      "recommended waiting for ${advice.wait!.recommendedMinutes} minutes",
                    );
                    logI("min waiting for ${advice.wait!.minMinutes} minutes");
                    logI("max waiting for ${advice.wait!.maxMinutes} minutes");
                    if (advice.wait!.recommendedMinutes == minutesLeft) {
                      nextExecutor = BolusThenWaitExecutor(
                        recommendedMinutes: advice.wait!.recommendedMinutes,
                      );
                      shouldAbort = true;
                    }
                    break;
                }
              }
              if (shouldAbort) break;

              try {
                deviceStatus = await waitForNextAvailableDeviceStatus(
                  runtimeContext,
                  6,
                );
              } catch (e) {
                deviceStatus = null;
                logI("No device status available for 6 minutes");
              }
            } while (--iterationsLeft > 0);

            // if device status is null means device status is old
            // if advice is null means we don't have advice available
            // but we don't want to show advice when device status is old
            if (advice == null || deviceStatus == null) {
              logI("No advice available going to idle state");
              return MealMonitorStateIdle();
            }

            // notify user about suggestion (if any)
            final notificationProvider = runtimeContext.container.read(
              notificationsControllerForegroundProvider,
            );
            notificationProvider.show(
              MealSuggestionNotificationEvent(
                mealId: mealMonitorContext.activeMeal!.id,
                minutes: advice.wait?.recommendedMinutes ?? 0,
                decision: advice.decision!,
                carbs: mealStatus.carbsG.round(),
              ),
            );

            final response = await runtimeContext
                .waitForEvent<MealSuggestionResponseEvent>();
            // if no response but device status came, recalculate
            var retry = false;
            logI("Received response from user");
            response.when(
              agree: (e) {
                final decisionStatus = advice!.decision!.status;
                logI("User agreed meal, decision: $decisionStatus");
                if (advice.decision == MealDecision.eatNowBolusLater) {
                  runtimeContext.container.read(
                    updateMealProvider(
                      mealMonitorContext.activeMeal!,
                      decisionStatus,
                    ),
                  );
                }
              },
              skip: (_) {
                logI("User dismissed meal, clicked on notification");
                runtimeContext.container.read(
                  updateMealProvider(mealMonitorContext.activeMeal!, 'skipped'),
                );
                nextExecutor = MealMonitorStateIdle();
              },
              snooze: (_, input) {
                logI("Snooze input: $input");
                final minutes = int.parse(input);
                normalizedMealTime = alignToNextCgmReading(
                  normalizedMealTime.add(Duration(minutes: minutes)),
                  deviceStatus!.date,
                );
                retry = true;
              },
              empty: (_) {
                logI("No action from user, clicked on notification he will continue in-app");
                nextExecutor = MealMonitorStateIdle();
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
