import 'package:clock/clock.dart';

import '../../../../../common/events/data/notification/eat_now_response_event.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/domain/events/eat_now_event_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/providers/meal_advisor_result_provider.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../providers/device_status_value_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'detect_finished_eating_executor.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';

class BolusThenWaitExecutor extends MealMonitorStateExecutor with Logging {
  int? recommendedMinutes;

  BolusThenWaitExecutor({this.recommendedMinutes});

  @override
  List<Type> get interruptableEvents => [MealStartedEatingEvent];

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
        logI("Problem gathering meal advice, going to idle state");
        return MealMonitorStateIdle();
      }
      //time passed from advice
      final timePassed = mealAdvice.createdAt.difference(clock.now());
      final recommendedWait = mealAdvice.wait!.recommendedMinutes;

      logI("Time passed from advice: ${timePassed.inMinutes} minutes");
      logI("Recommended wait: $recommendedWait minutes");
      recommendedMinutes = recommendedWait - timePassed.inMinutes;
      triggeredByUser = true;
      logI("Now will wait for $recommendedMinutes minutes");
    }

    logI("Waiting for calculator use before moving to next step");
    final calculatorResponse = await runtimeContext
        .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<BolusWizard>>(
          Duration(minutes: 20),
        );

    logI("Calculator response available, cancelling meal notifications");
    await notificationProvider.cancelAll();

    if (calculatorResponse == null) {
      logI("Problem gathering calculator response, going to idle state");
      return MealMonitorStateIdle();
    }

    if (!triggeredByUser) {
      await runtimeContext.container.read(
        updateMealProvider(
          mealMonitorContext.activeMeal!,
          'bolused-waiting',
        ).future,
      );
    }

    logI("Calculator response available");
    final waitIterations = recommendedMinutes! ~/ 5;
    logI("Waiting for $waitIterations iterations before showing eat now");
    for (var i = 0; i < waitIterations; i++) {
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

          final finalWaitTime = recommendedMinutes! - (i * 5);
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

        if (i == waitIterations - 1) {
          logI("Last iteration, ignoring wait");
          break;
        }

        logI("Waiting 5 minutes before next reading");
        final deviceStatusDuration = clock.now().difference(deviceStatus.date);
        final sleepDuration = Duration(minutes: 5) - deviceStatusDuration;
        logI(
          "Waiting for ${sleepDuration.inMinutes} $deviceStatusDuration minutes before next reading",
        );
        await runtimeContext.waitForDuration(sleepDuration);
        logI("wait end ");
      }
    }

    logI("triggered by user: $triggeredByUser, wait ended: $waitEnded");
    if (!triggeredByUser || waitEnded) {
      logI(
        "Waiting time shortened due to the condition $waitEnded or triggered by user $triggeredByUser, showing notification",
      );
      notificationProvider.show(
        EatNowNotificationEvent(
          mealId: mealMonitorContext.activeMeal!.id,
          minutes: 0,
        ),
      );
    }

    logI("Waiting for response");
    final response = await runtimeContext
        .waitForEventWithTimeoutOrNull<EatNowResponseEvent>(
          Duration(minutes: 10),
        );
    if (response == null) {
      logI("No response from user, going to idle state");
      return MealMonitorStateIdle();
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
        return DetectFinishedEatingExecutor(
          shouldBolus: false,
          bolusWaited: true,
        );
      },
      dismiss: (_) async {
        logI("Used dismissed meal, clicked on notification");
        return MealMonitorStateIdle();
      },
      empty: (_) async {
        logI(
          "User manually clicked on notification, he will probably continue in-app",
        );
        return MealMonitorStateIdle();
      },
    );
  }
}
