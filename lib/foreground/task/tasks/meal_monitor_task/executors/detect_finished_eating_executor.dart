import '../../../../../common/events/data/notification/finished_eating_response_event.dart';
import '../../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/base/notifications_controller.dart';
import '../../../../../core/notifications/domain/events/finished_eating_event_notification.dart';
import '../../../../../core/notifications/domain/events/meal_suggestion_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'finalize_meal_executor.dart';
import 'meal_monitor_state_executor.dart';
import 'new_meal_check_executor.dart';

class DetectFinishedEatingExecutor extends MealMonitorStateExecutor
    with Logging {
  static const _bolusReminderInterval = Duration(minutes: 5);

  final bool shouldBolus;
  final bool? bolusWaited;
  final bool isAddOn;
  int? grams;

  DetectFinishedEatingExecutor({
    required this.shouldBolus,
    this.grams,
    this.bolusWaited,
    this.isAddOn = false,
  });

  @override
  List<Type> get interruptableEvents => [
    MealEatingThenBolus,
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
    logI(
      "DetectFinishedEatingExecutor bolusWaited $bolusWaited shouldBolus $shouldBolus",
    );

    if (bolusWaited == null) {
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
            logI("Problem gathering meal advice, checking next meal");
            return NewMealCheckExecutor();
          }
          grams = mealSummary.netCarbsGrams.round();
          logI("Meal summary available with $grams grams of carbs");
        }
      } else {
        logI("Should not bolus");
        logI("Waiting for calculator use before moving to next step");
        final notificationProvider = runtimeContext.container.read(
          notificationsControllerForegroundProvider,
        );
        final calculatorResponse = await runtimeContext
            .waitForEventWithTimeoutOrNull<
              TreatmentAvailableEvent<BolusWizard>
            >(Duration(minutes: 20));

        if (calculatorResponse == null) {
          logI("Problem gathering calculator response, checking next meal");
          return NewMealCheckExecutor();
        }

        logI("Calculator response available, cancelling meal notifications");
        await notificationProvider.cancelAll();
        await runtimeContext.container.read(
          updateMealProvider(
            mealMonitorContext.activeMeal!,
            'bolused-eating',
          ).future,
        );
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

    var mealStatus = isAddOn ? 'eaten-extra' : 'eaten';

    if (shouldBolus) {
      final bolusRecorded = await _remindUntilBolusRecorded(
        runtimeContext,
        notificationProvider,
        mealMonitorContext.activeMeal!.id,
        carbs: grams!,
      );
      if (!bolusRecorded) {
        return NewMealCheckExecutor();
      }

      mealStatus = 'eaten-bolused';
    } else {
      logI("Finished eating, bolus already given");
    }

    await runtimeContext.container.read(
      updateMealProvider(mealMonitorContext.activeMeal!, mealStatus).future,
    );
    logI("Meal marked as $mealStatus");

    return FinalizeMealExecutor();
  }

  Future<bool> _remindUntilBolusRecorded(
    RuntimeContext runtimeContext,
    NotificationsController notificationProvider,
    int mealId, {
    required int carbs,
    bool isAddOn = false,
  }) async {
    var shouldCancelPreviousReminder = false;

    while (true) {
      if (shouldCancelPreviousReminder) {
        logI("Cancelling previous bolus reminder before showing next one");
        await notificationProvider.cancelAll();
      }

      logI("User should bolus after eating, showing notification");
      await notificationProvider.show(
        MealSuggestionNotificationEvent(
          mealId: mealId,
          decision: MealDecision.bolus,
          carbs: carbs,
          minutes: 0,
          isAddOn: isAddOn,
        ),
      );
      shouldCancelPreviousReminder = true;

      logI("Notification shown, waiting for user response or calculator");
      final result = await _waitForBolusReminderResult(runtimeContext, mealId);

      if (result == null) {
        logI("Bolus reminder timed out, showing it again");
        continue;
      }

      if (result is TreatmentAvailableEvent<BolusWizard>) {
        logI(
          "Calculator response available, cancelling notifications and marking meal as bolused eaten",
        );
        await notificationProvider.cancelAll();
        return true;
      }

      final response = result as MealSuggestionResponseEvent;
      logI("Got response from user");

      var delay = _bolusReminderInterval;
      var shouldContinue = true;

      response.when(
        agree: (int mealId) {
          logI("User agreed to bolus");
        },
        skip: (int mealId) {
          logI("User skipped meal suggestion");
          shouldContinue = false;
        },
        snooze: (int mealId, String input) {
          logI("User snoozed meal suggestion");
          delay = Duration(
            minutes: int.tryParse(input) ?? _bolusReminderInterval.inMinutes,
          );
        },
        empty: (int mealId) {
          logI("User clicked on notification probably by mistake");
        },
      );

      if (!shouldContinue) {
        return false;
      }

      final bolusResponse = await runtimeContext
          .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<BolusWizard>>(
            delay,
          );
      if (bolusResponse != null) {
        logI(
          "Calculator response available, cancelling notifications and marking meal as bolused eaten",
        );
        await notificationProvider.cancelAll();
        return true;
      }

      logI("Calculator response missing after reminder delay, reminding again");
    }
  }

  Future<ForegroundEvent?> _waitForBolusReminderResult(
    RuntimeContext runtimeContext,
    int mealId,
  ) async {
    final responseHandle = runtimeContext
        .eventWait<MealSuggestionResponseEvent>(
          predicate: (event) => event.mealId == mealId,
        );
    final bolusHandle = runtimeContext
        .eventWait<TreatmentAvailableEvent<BolusWizard>>();
    final timeoutHandle = runtimeContext.durationWait(_bolusReminderInterval);

    return runtimeContext.any<ForegroundEvent?>([
      responseHandle.map<ForegroundEvent?>((event) => event),
      bolusHandle.map<ForegroundEvent?>((event) => event),
      timeoutHandle.map<ForegroundEvent?>((_) => null),
    ]);
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

    final grams = await _resolveAddOnNetCarbs(
      runtimeContext,
      mealMonitorContext.activeMeal!.id,
    );
    logI("Add-on calculator response missing, showing reminder");

    return _remindUntilBolusRecorded(
      runtimeContext,
      runtimeContext.container.read(notificationsControllerForegroundProvider),
      mealMonitorContext.activeMeal!.id,
      carbs: grams,
      isAddOn: true,
    );
  }

  Future<int> _resolveAddOnNetCarbs(
    RuntimeContext runtimeContext,
    int mealId,
  ) async {
    final plannedSummary = await runtimeContext.container.read(
      mealMacronutrientsSummaryProvider(mealId).future,
    );
    final consumedSummary = await runtimeContext.container.read(
      mealMacronutrientsConsumedSummaryProvider(mealId).future,
    );
    final addOnNetCarbs =
        _netCarbs(consumedSummary) - _netCarbs(plannedSummary);
    if (addOnNetCarbs <= 0) {
      return 0;
    }
    return addOnNetCarbs.round();
  }

  double _netCarbs(MealMacroSummary? summary) {
    if (summary == null) {
      return 0;
    }
    final netCarbs = summary.carbsGrams - summary.fiberGrams;
    return netCarbs < 0 ? 0 : netCarbs;
  }
}
