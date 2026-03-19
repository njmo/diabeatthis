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
import 'wait_after_bolus_executor.dart';

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
    print("MonitorUntilMeal shouldInterrupt ${event.runtimeType}");
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
    print("WaitUntilEatingExecutor cleanup");
  }

  Future<DeviceStatus> getOrWaitForNextAvailableDeviceStatus(
    RuntimeContext context,
    int maxMinutes,
  ) {
    final deviceStatus = context.container.read(deviceStatusValueProvider);
    if (deviceStatus != null) {
      print("device status available from beginning");
      return Future.value(deviceStatus);
    }
    return waitForNextAvailableDeviceStatus(context, maxMinutes);
  }

  Future<DeviceStatus> waitForNextAvailableDeviceStatus(
    RuntimeContext context,
    int maxMinutes,
  ) async {
    print("waiting for device status");
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

    print(
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
    print("WaitUntilEatingExecutor");

    if (mealMonitorContext.activeMeal == null) {
      print("No meal to monitor");
      return MealMonitorStateIdle();
    }
    final mealPlannedAt = mealMonitorContext.activeMeal!.plannedAt!;
    final timeToMeal = mealPlannedAt.difference(DateTime.now());
    print("Meal planned at ${mealPlannedAt.toIso8601String()}");
    print("Time to meal ${timeToMeal.inMinutes}");

    DeviceStatus? deviceStatus;

    DateTime normalizedMealTime;
    try {
      normalizedMealTime = await normalizeMealTime(
        runtimeContext,
        timeToMeal,
        mealPlannedAt,
      );
    } catch (e) {
      print("Problem normalizing meal time");
      return MealMonitorStateIdle();
    }

    final timeToMealNormalized = normalizedMealTime.difference(DateTime.now());
    print("Normalized meal planned at ${normalizedMealTime.toIso8601String()}");
    print("Time to meal ${timeToMealNormalized.inMinutes}");

    final mealAdvisorBuffer = 5;
    if (timeToMealNormalized.inMinutes < mealAdvisorBuffer) {
      print("User probably added new meal manually using quick method");
      // will wait for user further actions.
      return MealMonitorStateIdle();
    }

    while (true) {
      final now = DateTime.now();
      final timeToMeal = normalizedMealTime.difference(now);
      final pathDecision = detectPathDecision(timeToMeal);
      final maxWaitMinutes = minutesTillNextPath(timeToMeal);
      print("Time now ${now.toIso8601String()}");
      print("Path decision: $pathDecision");
      print("Max wait minutes: $maxWaitMinutes");
      print("Time to meal: ${timeToMeal.inMinutes}");

      try {
        switch (pathDecision) {
          case PathDecision.abort:
            print("No path decision available going to idle state");
            return MealMonitorStateIdle();
          case PathDecision.waitUntilMealMonitorWindow:
            print(
              "Duration till meal ${timeToMeal.inMinutes} waiting for monitoring window",
            );
            await runtimeContext.waitForDuration(
              Duration(minutes: maxWaitMinutes),
            );
          case PathDecision.temporaryTargetSuggestion:
            print(
              "Duration till meal ${timeToMeal.inMinutes} waiting for glucose",
            );
            final deviceStatus = await getOrWaitForNextAvailableDeviceStatus(
              runtimeContext,
              maxWaitMinutes,
            );
            print("Blood sugar value: ${deviceStatus.bg}");
            if (deviceStatus.bg > 100) {
              print("showing temp target suggestion notification");
              showTempTargetNotification(runtimeContext);

              print("showing notification done sleeping till next path");
              await runtimeContext.waitForDuration(
                Duration(minutes: maxWaitMinutes),
              );
            }
            break;
          case PathDecision.mealAdvisor:
            print("building macro status");
            // build meal macronutrient status
            final mealStatus = await runtimeContext.container.read(
              mealMacronutrientsSummaryProvider(
                mealMonitorContext.activeMeal!.id,
              ).future,
            );

            if (mealStatus == null) {
              print("Problem gathering meal macronutrients status");
              // notify to use phone
              return MealMonitorStateIdle();
            }

            MealMonitorStateExecutor nextExecutor = MealMonitorStateIdle();
            var shouldAbort = false;
            MealAdvice? advice;

            var iterationsLeft = (timeToMeal.inMinutes / 5).floor() + 2;
            do {
              print("iterationsLeft $iterationsLeft");
              deviceStatus = runtimeContext.container.read(
                deviceStatusValueProvider,
              );
              if (deviceStatus != null) {
                print(
                  'deviceStatus: $iterationsLeft date ${deviceStatus.date.toIso8601String()} now ${DateTime.now().toIso8601String()} meal planned at ${mealPlannedAt.toIso8601String()}',
                );
                advice = getMealAdvice(mealStatus, deviceStatus);

                final iterationsRemaining = iterationsLeft - 1;
                final minutesLeft = iterationsRemaining * 5;
                print("iterations remaining $iterationsRemaining");
                print("minutes left $minutesLeft");

                switch (advice.decision!) {
                  case MealDecision.eatNowBolusLater:
                    print("Meal advice: ${advice.decision.toString()}");
                    nextExecutor = DetectFinishedEatingExecutor(
                      shouldBolus: true,
                      grams: mealStatus.carbsG.round(),
                    );
                    break;
                  case MealDecision.bolusAndEatNow:
                    print("Meal advice: ${advice.decision.toString()}");
                    // need to store meal information for notification
                    // wait more time to return right before meal
                    nextExecutor = DetectFinishedEatingExecutor(
                      shouldBolus: false,
                    );
                    break;
                  case MealDecision.bolusWaitThenEat:
                    print("Meal advice: ${advice.decision.toString()}");
                    print(
                      "recommended waiting for ${advice.wait!.recommendedMinutes} minutes",
                    );
                    print("min waiting for ${advice.wait!.minMinutes} minutes");
                    print("max waiting for ${advice.wait!.maxMinutes} minutes");
                    if (advice.wait!.recommendedMinutes == minutesLeft) {
                      nextExecutor = WaitAfterBolusExecutor(
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
                print("No device status available for 6 minutes");
              }
            } while (--iterationsLeft > 0);

            // if device status is null means device status is old
            // if advice is null means we don't have advice available
            // but we don't want to show advice when device status is old
            if (advice == null || deviceStatus == null) {
              print("No advice available going to idle state");
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
            print("Received response from user");
            response.when(
              agree: (e) {
                final decisionStatus = advice!.decision!.status;
                print("Used agreed meal");
                runtimeContext.container.read(
                  updateMealProvider(
                    mealMonitorContext.activeMeal!,
                    decisionStatus,
                  ),
                );
              },
              skip: (_) {
                print("Used dismissed meal, clicked on notification");
                runtimeContext.container.read(
                  updateMealProvider(mealMonitorContext.activeMeal!, 'skipped'),
                );
              },
              snooze: (_, input) {
                print("Snooze input: $input");
                final minutes = int.parse(input);
                normalizedMealTime = alignToNextCgmReading(
                  normalizedMealTime.add(Duration(minutes: minutes)),
                  deviceStatus!.date,
                );
                retry = true;
              },
              empty: (_) {
                print("No action from user, clicked on notification");
              },
            );

            if (retry) {
              print(
                "Retrying with new meal planned at ${normalizedMealTime.toIso8601String()}",
              );
              continue;
            }

            return nextExecutor;
        }
      } on WaitTimeoutException catch (_) {
        print("Problem reading data, moving to next step");
        continue;
      }
    }
  }
}
