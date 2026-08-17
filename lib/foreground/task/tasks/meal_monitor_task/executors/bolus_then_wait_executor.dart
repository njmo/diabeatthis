import 'package:clock/clock.dart';

import '../../../../../common/events/data/notification/eat_now_response_event.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/base/notifications_controller.dart';
import '../../../../../core/notifications/domain/events/eat_now_event_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/providers/meal_advisor_result_provider.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../../providers/device_status_value_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'detect_finished_eating_executor.dart';
import 'meal_monitor_state_executor.dart';
import 'new_meal_check_executor.dart';

class BolusThenWaitExecutor extends MealMonitorStateExecutor with Logging {
  int? recommendedMinutes;

  BolusThenWaitExecutor({this.recommendedMinutes});

  @override
  List<Type> get interruptableEvents => [
    MealStartedEatingEvent,
    MealWaitedEatingEvent,
  ];

  @override
  bool shouldInterrupt(
    ForegroundEvent event,
    MealMonitorContext mealMonitorContext,
  ) {
    logI("BolusThenWaitExecutor shouldInterrupt ${event.runtimeType}");
    if (event is MealStatusChangedEvent) {
      return event.mealId == mealMonitorContext.activeMeal!.id;
    }
    return true;
  }

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) {
    logI("MealMonitorStateWaitAfterBolus cleanup");
    return Future.value();
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("MealMonitorStateWaitAfterBolus");
    logI("Meal scheduled on ${mealMonitorContext.activeMeal!.plannedAt}");
    final notificationProvider = runtimeContext.container.read(
      notificationsControllerForegroundProvider,
    );
    var triggeredByUser = false;
    var waitEnded = false;

    // it means that user manually went through starting the meal earlier than
    // planned.
    if (recommendedMinutes == null) {
      logI("User manually went through starting the meal earlier than planned");
      final mealAdvice = await runtimeContext.container.read(
        getMealAdviceProvider(mealMonitorContext.activeMeal!).future,
      );
      if (mealAdvice == null) {
        logI("Problem gathering meal advice, checking next meal");
        return NewMealCheckExecutor();
      }
      final recommendedWait = mealAdvice.wait!.recommendedMinutes;

      logI("Recommended wait: $recommendedWait minutes");
      recommendedMinutes = recommendedWait;
      triggeredByUser = true;
      logI("Now will wait for $recommendedMinutes minutes");
    }

    if (!triggeredByUser) {
      await runtimeContext.container.read(
        updateMealProvider(
          mealMonitorContext.activeMeal!,
          'bolused-waiting',
        ).future,
      );
    }

    logI("Bolus already recorded, starting wait after bolus");
    final waitStartedAt = clock.now();
    logI("Waiting for $recommendedMinutes minutes before showing eat now");
    while (_elapsedWaitMinutes(waitStartedAt) < recommendedMinutes!) {
      final deviceStatus = runtimeContext.container.read(
        deviceStatusValueProvider,
      );
      if (deviceStatus == null) {
        logI(
          "Problem gathering blood sugar value, waiting 5 minutes for next reading",
        );
        await runtimeContext.waitForDuration(Duration(minutes: 5));
      } else {
        final tick = int.tryParse(deviceStatus.tick) ?? 0;
        logI(
          "Blood sugar value: ${deviceStatus.bg} read at ${deviceStatus.date.toIso8601String()} tick $tick",
        );
        if (tick < -10 && deviceStatus.bg < 180) {
          logI("Can eat earlier, sugar drops faster than usual");
          if (triggeredByUser) {
            logI("Cancelling scheduled notifications");
            notificationProvider.cancelAll();
          }

          final finalWaitTime = _elapsedWaitMinutes(waitStartedAt);
          logI("Updating final wait time to $finalWaitTime");
          runtimeContext.container.read(
            updateFinalWaitTimeProvider(
              mealMonitorContext.activeMeal!,
              finalWaitTime,
            ),
          );
          waitEnded = true;
          break;
        }

        logI("Waiting before next reading");
      }

      final elapsedMinutes = _elapsedWaitMinutes(waitStartedAt);
      final remainingMinutes = recommendedMinutes! - elapsedMinutes;
      if (remainingMinutes <= 0) {
        break;
      }
      final sleepMinutes = remainingMinutes < 5 ? remainingMinutes : 5;
      logI("Waiting for $sleepMinutes minutes before next reading");
      await runtimeContext.waitForDuration(Duration(minutes: sleepMinutes));
      logI("wait end ");
    }

    logI("triggered by user: $triggeredByUser, wait ended: $waitEnded");
    logI("Bolus wait completed, showing eat now notification");

    logI("Waiting for response");
    final response = await _waitForEatNowResponse(
      runtimeContext: runtimeContext,
      notificationProvider: notificationProvider,
      mealId: mealMonitorContext.activeMeal!.id,
      showInitialNotification: true,
      waitStartedAt: waitStartedAt,
    );
    if (response == null) {
      logI("No response from user, checking next meal");
      return NewMealCheckExecutor();
    }

    logI("Received response from user");
    return response.when<Future<MealMonitorStateExecutor>>(
      eating: (_) async {
        logI("Used agreed meal");
        await runtimeContext.container.read(
          updateMealProvider(
            mealMonitorContext.activeMeal!,
            'waited-eating',
          ).future,
        );
        return DetectFinishedEatingExecutor(shouldBolus: false);
      },
      dismiss: (_) async {
        logI("Used dismissed meal, clicked on notification");
        return NewMealCheckExecutor();
      },
      empty: (_) async {
        logI(
          "User manually clicked on notification, he will probably continue in-app",
        );
        return NewMealCheckExecutor();
      },
    );
  }

  Future<EatNowResponseEvent?> _waitForEatNowResponse({
    required RuntimeContext runtimeContext,
    required NotificationsController notificationProvider,
    required int mealId,
    required bool showInitialNotification,
    required DateTime waitStartedAt,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final shouldShowNotification = attempt > 0 || showInitialNotification;
      if (shouldShowNotification) {
        logI("Showing eat now notification attempt ${attempt + 1}");
        await notificationProvider.cancelAll();
        await notificationProvider.show(
          EatNowNotificationEvent(
            mealId: mealId,
            minutes: _elapsedWaitMinutes(waitStartedAt),
          ),
        );
      }

      final response = await runtimeContext
          .waitForEventWithTimeoutOrNull<EatNowResponseEvent>(
            Duration(minutes: 10),
          );
      if (response != null) {
        return response;
      }
    }
    await notificationProvider.cancelAll();
    return null;
  }

  int _elapsedWaitMinutes(DateTime waitStartedAt) {
    final elapsed = clock.now().difference(waitStartedAt).inMinutes;
    if (elapsed < 0) {
      return 0;
    }
    return elapsed;
  }
}
