import 'package:clock/clock.dart';

import '../../../../../common/events/data/notification/finished_eating_response_event.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/domain/events/finished_eating_event_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../base/runtime_context.dart';
import '../helpers/bolus_reminder_helper.dart';
import '../meal_monitor_context.dart';
import 'finalize_meal_executor.dart';
import 'meal_monitor_state_executor.dart';
import 'new_meal_check_executor.dart';
import 'wait_for_bolus_executor.dart';

class DetectFinishedEatingExecutor extends MealMonitorStateExecutor
    with Logging {
  final BolusReminderHelper _bolusReminderHelper = BolusReminderHelper();

  final bool shouldBolus;
  final bool isAddOn;
  int? grams;

  DetectFinishedEatingExecutor({
    required this.shouldBolus,
    this.grams,
    this.isAddOn = false,
  });

  @override
  List<Type> get interruptableEvents => [
    MealEatingThenBolus,
    MealWaitingForBolusEvent,
    MealEatingExtraEvent,
    MealFinishedEatingEvent,
    MealFinishedEatingExtraEvent,
    MealFinishedEatingBolusedEvent,
  ];

  @override
  bool shouldInterrupt(
    ForegroundEvent event,
    MealMonitorContext mealMonitorContext,
  ) {
    logI("DetectFinishedEatingExecutor shouldInterrupt ${event.runtimeType}");
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
    logI("DetectFinishedEatingExecutor cleanup");
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("DetectFinishedEatingExecutor shouldBolus $shouldBolus");

    if (isAddOn) {
      final bolusRecorded = await _waitForAddOnBolus(
        runtimeContext,
        mealMonitorContext,
      );
      if (!bolusRecorded) {
        return NewMealCheckExecutor();
      }
    } else if (shouldBolus) {
      logI("Checking if needed data is present");
      // if below passes it means that user manually went
      // through starting the meal earlier than planned.
      if (grams == null) {
        logI(
          "User manually went through starting the meal earlier than planned",
        );
        final mealSummary = await runtimeContext.container.read(
          mealMacronutrientsConsumedSummaryProvider(
            mealMonitorContext.activeMeal!.id,
          ).future,
        );
        if (mealSummary == null) {
          logI(
            "Problem gathering consumed meal summary, continuing finished meal detection",
          );
        } else {
          grams = mealSummary.netCarbsGrams.ceil();
          logI("Meal summary available with $grams grams of carbs");
        }
      }
    }

    final notificationProvider = runtimeContext.container.read(
      notificationsControllerForegroundProvider,
    );
    // jezeli zacznie jesc to przez te 10 minut mozna monitorowac cukier i zerknac
    // czy czasem nie lepiej juz podac sobie insuline jak teraz gdzie jadl i mial 101
    // mozna bylo dac powiadomienie juz zeby dal sobie insuline
    logI("Waiting for user to end his meal");
    await runtimeContext.waitForDuration(Duration(minutes: 5));
    logI("Ended waiting for user to end his meal");

    var shouldContinue = true;
    while (shouldContinue) {
      logI("Showing user notification if he finished eating");
      notificationProvider.show(
        FinishedEatingNotificationEvent(
          mealId: mealMonitorContext.activeMeal!.id,
          isAddOn: isAddOn,
        ),
      );
      logI("Notification shown, waiting for user response");
      final response = await runtimeContext
          .waitForEvent<FinishedEatingResponseEvent>();
      logI("Got response from user");

      await response.when<Future<void>>(
        agree: (int mealId) async {
          logI("User agreed he finished eating");
          shouldContinue = false;
        },
        snooze: (int mealId) async {
          logI("Snoozing for 5 more minutes");
          await runtimeContext.waitForDuration(Duration(minutes: 5));
        },
        empty: (int mealId) async {
          logI("User clicked on notification probably by mistake, show again");
        },
      );
    }

    final mealStatus = isAddOn ? 'eaten-extra' : 'eaten';

    if (shouldBolus) {
      await runtimeContext.container.read(
        updateMealProvider(
          mealMonitorContext.activeMeal!,
          'waiting-for-bolus',
        ).future,
      );
      logI("Meal waiting for bolus after eating");
      return WaitForBolusExecutor(
        remindImmediately: true,
        initialAdvice: MealAdvice.full(
          MealDecision.eatNowBolusLater,
          null,
          clock.now(),
        ),
      );
    } else {
      logI("Finished eating, bolus already given");
    }

    await runtimeContext.container.read(
      updateMealProvider(mealMonitorContext.activeMeal!, mealStatus).future,
    );
    logI("Meal marked as $mealStatus");

    return FinalizeMealExecutor();
  }

  Future<bool> _waitForAddOnBolus(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("Waiting for add-on calculator response");
    final calculatorResponse = await runtimeContext
        .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<BolusWizard>>(
          Duration(minutes: 10),
        );

    if (calculatorResponse != null) {
      logI("Add-on calculator response available, cancelling notifications");
      await runtimeContext.container
          .read(notificationsControllerForegroundProvider)
          .cancelAll();
      return true;
    }

    final grams = await _bolusReminderHelper.resolveAddOnNetCarbs(
      runtimeContext,
      mealMonitorContext.activeMeal!.id,
    );
    logI("Add-on calculator response missing, showing reminder");

    return _bolusReminderHelper.remindUntilBolusRecorded(
      runtimeContext,
      runtimeContext.container.read(notificationsControllerForegroundProvider),
      mealMonitorContext.activeMeal!.id,
      carbs: grams,
      isAddOn: true,
    );
  }
}
