import '../../../../../common/events/data/notification/finished_eating_response_event.dart';
import '../../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/domain/events/finished_eating_event_notification.dart';
import '../../../../../core/notifications/domain/events/meal_suggestion_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'finalize_meal_executor.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';

class DetectFinishedEatingExecutor extends MealMonitorStateExecutor
    with Logging {
  final bool shouldBolus;
  final bool? bolusWaited;
  int? grams;

  DetectFinishedEatingExecutor({
    required this.shouldBolus,
    this.grams,
    this.bolusWaited,
  });

  @override
  List<Type> get interruptableEvents => [
    MealFinishedEatingEvent,
  ];

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("DetectFinishedEatingExecutor cleanup");
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("DetectFinishedEatingExecutor bolusWaited $bolusWaited shouldBolus $shouldBolus");

    if (bolusWaited == null) {
      if (shouldBolus) {
        logI("Checking if needed data is present");
        // if below passes it means that user manually went
        // through starting the meal earlier than planned.
        if (grams == null) {
          logI(
            "User manually went through starting the meal earlier than planned",
          );
          final mealSummary = await runtimeContext.container.read(
            mealMacronutrientsSummaryProvider(
              mealMonitorContext.activeMeal!.id,
            ).future,
          );
          if (mealSummary == null) {
            logI("Problem gathering meal advice, going to idle state");
            return MealMonitorStateIdle();
          }
          grams = mealSummary.netCarbsGrams.round();
          logI("Meal summary available with $grams grams of carbs");
        }
      } else {
        logI("Should not bolus");
        logI("Waiting for calculator use before moving to next step");
        final calculatorResponse = await runtimeContext
            .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<Meal>>(
              Duration(minutes: 20),
            );

        if (calculatorResponse == null) {
          logI("Problem gathering calculator response, going to idle state");
          return MealMonitorStateIdle();
        }

        logI("Calculator response available");
        runtimeContext.container.read(
          updateMealProvider(mealMonitorContext.activeMeal!, 'bolused-eating'),
        );
      }
    }

    final notificationProvider = runtimeContext.container.read(
      notificationsControllerForegroundProvider,
    );

    logI("Waiting for user to end his meal");
    await runtimeContext.waitForDuration(Duration(minutes: 10));
    logI("Ended waiting for user to end his meal");

    var shouldContinue = true;
    while (shouldContinue) {
      logI("Showing user notification if he finished eating");
      notificationProvider.show(
        FinishedEatingNotificationEvent(
          mealId: mealMonitorContext.activeMeal!.id,
        ),
      );
      logI("Notification shown, waiting for user response");
      final response = await runtimeContext
          .waitForEvent<FinishedEatingResponseEvent>();
      logI("Got response from user");

      response.when(
        agree: (int mealId) {
          logI("User agreed he finished eating");
          shouldContinue = false;
        },
        snooze: (int mealId) async {
          logI("Snoozing for 5 more minutes");
          await runtimeContext.waitForDuration(Duration(minutes: 5));
        },
        empty: (int mealId) {
          logI("User clicked on notification probably by mistake, show again");
        },
      );
    }

    var mealStatus = 'eaten';

    if (shouldBolus) {
      logI("User should bolus after eating, showing notification");
      notificationProvider.show(
        MealSuggestionNotificationEvent(
          mealId: mealMonitorContext.activeMeal!.id,
          decision: MealDecision.bolus,
          carbs: grams!,
          minutes: 0,
        ),
      );
      logI("Notification shown, waiting for user response");
      final response = await runtimeContext
          .waitForEvent<MealSuggestionResponseEvent>();
      logI("Got response from user");

      response.when(
        agree: (e) {
          logI("User agreed to bolus");
        },
        skip: (int mealId) {
          logI("User skipped meal suggestion");
          return MealMonitorStateIdle();
        },
        snooze: (int mealId, String input) {
          logI("User snoozed meal suggestion");
        },
        empty: (int mealId) {
          logI("User clicked on notification probably by mistake");
        },
      );

      await runtimeContext.waitForEvent<TreatmentAvailableEvent<Meal>>();
      logI("Calculator response available, marking meal as bolused eaten");

      mealStatus = 'bolused-eaten';
    } else {
      logI("Finished eating, bolus already given");
    }

    runtimeContext.container.read(
      updateMealProvider(mealMonitorContext.activeMeal!, mealStatus),
    );
    logI("Meal marked as $mealStatus");

    return FinalizeMealExecutor();
  }
}
