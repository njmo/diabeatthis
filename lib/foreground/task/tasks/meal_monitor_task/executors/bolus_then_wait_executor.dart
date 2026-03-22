import '../../../../../common/events/data/notification/eat_now_response_event.dart';
import '../../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/domain/events/eat_now_event_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/providers/meal_advisor_result_provider.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../providers/device_status_value_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'detect_finished_eating_executor.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';

class BolusThenWaitExecutor extends MealMonitorStateExecutor with Logging {
  late final int? recommendedMinutes;

  BolusThenWaitExecutor({this.recommendedMinutes});

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) {
    print("MealMonitorStateWaitAfterBolus cleanup");
    return Future.value();
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("MealMonitorStateWaitAfterBolus");
    final notificationProvider = runtimeContext.container.read(
      notificationsControllerForegroundProvider,
    );
    var triggeredByUser = false;

    // it means that user manually went through starting the meal earlier than
    // planned.
    if (recommendedMinutes != null) {
      final mealAdvice = await runtimeContext.container.read(
        getMealAdviceProvider(mealMonitorContext.activeMeal!).future,
      );
      if (mealAdvice == null) {
        logI("Problem gathering meal advice, going to idle state");
        return MealMonitorStateIdle();
      }
      recommendedMinutes = mealAdvice.wait!.recommendedMinutes;
      triggeredByUser = true;
    }

    logI("Waiting for calculator use before moving to next step");
    final calculatorResponse = await runtimeContext
        .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<Meal>>(
          Duration(minutes: 20),
        );

    if (calculatorResponse == null) {
      logI("Problem gathering calculator response, going to idle state");
      return MealMonitorStateIdle();
    }

    runtimeContext.container.read(
      updateMealProvider(mealMonitorContext.activeMeal!, 'bolused-waiting'),
    );

    logI("Calculator response available");
    final waitIterations = 3;
    for (var i = 0; i < waitIterations; i++) {
      final deviceStatus = runtimeContext.container.read(
        deviceStatusValueProvider,
      );
      if (deviceStatus == null) {
        logI("Problem gathering blood sugar value, waiting 5 minutes for next reading");
        runtimeContext.waitForDuration(Duration(minutes: 5));
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
          break;
        }
        final sleepDuration = Duration(minutes:5) - deviceStatus.date.difference(DateTime.now());
        runtimeContext.waitForDuration(sleepDuration);
      }
    }

    logI("Finished waiting for calculator use");

    notificationProvider.show(
      EatNowNotificationEvent(
        mealId: mealMonitorContext.activeMeal!.id,
        minutes: 0,
      ),
    );
    final response = await runtimeContext
        .waitForEventWithTimeoutOrNull<EatNowResponseEvent>(
          Duration(minutes: 10),
        );
    if (response == null) {
      logI("No response from user, going to idle state");
      return MealMonitorStateIdle();
    }

    logI("Received response from user");
    response.when(
      eating: (_) {
        logI("Used agreed meal");
        runtimeContext.container.read(
          updateMealProvider(mealMonitorContext.activeMeal!, 'eating'),
        );
      },
      dismiss: (_) {
        logI("Used dismissed meal, clicked on notification");
        return MealMonitorStateIdle();
      },
      empty: (_) {
        logI("User manually clicked on notification, he will probably continue in-app");
        return MealMonitorStateIdle();
      },
    );

    return DetectFinishedEatingExecutor(shouldBolus: false);
  }
}
