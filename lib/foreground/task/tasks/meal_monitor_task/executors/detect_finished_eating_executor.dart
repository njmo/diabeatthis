import 'dart:collection';

import 'package:clock/clock.dart';

import '../../../../../common/events/data/notification/finished_eating_response_event.dart';
import '../../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../../common/notifications/meal_notification_cancellation.dart';
import '../../../../../common/notifications/scoped_notification_cancellation.dart';
import '../../../../../common/nutrition/stable_macro_ceil.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/domain/events/finished_eating_event_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/meals/common/models/meal_wizard_relation_type.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../../providers/latest_bolus_wizard_provider.dart';
import '../../../base/runtime_context.dart';
import '../helpers/bolus_reminder_helper.dart';
import '../helpers/meal_add_on_bolus_waiter.dart';
import '../helpers/record_meal_wizard_link.dart';
import '../helpers/wait_for_meal_bolus_delivery.dart';
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
    MealSkippedEvent,
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
    mealMonitorContext.publishStatus(
      runtimeContext,
      isAddOn
          ? MealMonitoringPhase.waitingForBolus
          : shouldBolus
          ? MealMonitoringPhase.eatingThenBolus
          : MealMonitoringPhase.eating,
    );
    logI("DetectFinishedEatingExecutor shouldBolus $shouldBolus");

    if (isAddOn) {
      final bolusRecorded = await _waitForAddOnBolus(
        runtimeContext,
        mealMonitorContext,
      );
      if (!bolusRecorded) {
        return NewMealCheckExecutor();
      }
      mealMonitorContext.publishStatus(
        runtimeContext,
        MealMonitoringPhase.eatingExtra,
      );
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
        mealMonitorContext.throwIfStopped(runtimeContext);
        if (mealSummary == null) {
          logI(
            "Problem gathering consumed meal summary, continuing finished meal detection",
          );
        } else {
          grams = mealSummary.netCarbsGrams.ceilMacro();
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

    final notification = FinishedEatingNotificationEvent(
      mealId: mealMonitorContext.activeMeal!.id,
      isAddOn: isAddOn,
    );
    const retryDelay = Duration(minutes: 5);
    final inbox = runtimeContext.openEventInbox<FinishedEatingResponseEvent>();
    final responses = Queue<FinishedEatingResponseEvent>();
    Future<FinishedEatingResponseEvent> nextResponse({
      required bool confirming,
    }) async {
      while (true) {
        if (responses.isEmpty) responses.addAll(await inbox.nextBatch());
        while (responses.isNotEmpty) {
          final response = responses.removeFirst();
          if (response.mealId != notification.mealId) continue;
          if (response.maybeWhen(
            agree: (_) => true,
            snooze: (_) => !confirming,
            confirmationPending: (_) => !confirming,
            confirmationDismissed: (_) => confirming,
            orElse: () => false,
          )) {
            return response;
          }
        }
      }
    }

    try {
      while (true) {
        final pendingResponse = nextResponse(confirming: false);
        pendingResponse.ignore();
        late final FinishedEatingResponseEvent response;
        try {
          mealMonitorContext.throwIfStopped(runtimeContext);
          await notificationProvider.show(notification);
          response = await runtimeContext.interruptController.race(
            pendingResponse,
          );
        } finally {
          try {
            await notificationProvider.cancelNotification(notification.key);
          } catch (error) {
            logW('Could not clear finished eating notification: $error');
          }
        }

        var answer = response;
        if (answer.maybeWhen(
          confirmationPending: (_) => true,
          orElse: () => false,
        )) {
          answer = await runtimeContext.interruptController.race(
            nextResponse(confirming: true),
          );
        }
        if (answer.maybeWhen(agree: (_) => true, orElse: () => false)) break;
        await runtimeContext.waitForDuration(retryDelay);
      }
    } finally {
      inbox.close();
    }

    mealMonitorContext.throwIfStopped(runtimeContext);
    final mealStatus = isAddOn ? 'eaten-extra' : 'eaten';

    if (shouldBolus) {
      await runtimeContext.container.read(
        updateMealProvider(
          mealMonitorContext.activeMeal!,
          'waiting-for-bolus',
        ).future,
      );
      mealMonitorContext.throwIfStopped(runtimeContext);
      logI("Meal waiting for bolus after eating");
      return WaitForBolusExecutor(
        remindImmediately: true,
        confirmedCarbs: grams,
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
    mealMonitorContext.throwIfStopped(runtimeContext);
    logI("Meal marked as $mealStatus");

    return FinalizeMealExecutor();
  }

  Future<bool> _waitForAddOnBolus(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("Waiting for add-on calculator response");
    final persisted = await const MealAddOnBolusWaiter()(
      runtimeContext,
      mealMonitorContext,
      remindImmediately: false,
    );
    if (persisted != null) return persisted;
    final calculatorResponse = await runtimeContext
        .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<BolusWizard>>(
          Duration(minutes: 10),
        );

    if (calculatorResponse != null) {
      logI("Add-on calculator response available, cancelling notifications");
      await runtimeContext.container
          .read(notificationsControllerForegroundProvider)
          .cancelMealNotifications(mealMonitorContext.activeMeal!.id);
      mealMonitorContext.throwIfStopped(runtimeContext);
      final confirmed = await const WaitForMealBolusDelivery()(
        runtimeContext,
        mealMonitorContext,
        calculatorResponse.data,
      );
      mealMonitorContext.throwIfStopped(runtimeContext);
      await const RecordMealWizardLink()(
        runtimeContext,
        confirmed.wizard,
        mealMonitorContext.activeMeal!.id,
        type: MealWizardRelationType.continuation,
      );
      mealMonitorContext.throwIfStopped(runtimeContext);
      consumeBolusWizard(runtimeContext.container, confirmed.wizard);
      return true;
    }

    final grams = await _bolusReminderHelper.resolveAddOnNetCarbs(
      runtimeContext,
      mealMonitorContext.activeMeal!.id,
    );
    mealMonitorContext.throwIfStopped(runtimeContext);
    logI("Add-on calculator response missing, showing reminder");

    return _bolusReminderHelper.remindUntilBolusRecorded(
      runtimeContext,
      runtimeContext.container.read(notificationsControllerForegroundProvider),
      mealMonitorContext.activeMeal!.id,
      carbs: grams,
      isAddOn: true,
      ensureActive: () => mealMonitorContext.throwIfStopped(runtimeContext),
      onBolusRecorded: (wizard) async {
        final confirmed = await const WaitForMealBolusDelivery()(
          runtimeContext,
          mealMonitorContext,
          wizard,
        );
        mealMonitorContext.throwIfStopped(runtimeContext);
        await const RecordMealWizardLink()(
          runtimeContext,
          confirmed.wizard,
          mealMonitorContext.activeMeal!.id,
          type: MealWizardRelationType.continuation,
        );
        mealMonitorContext.throwIfStopped(runtimeContext);
        consumeBolusWizard(runtimeContext.container, confirmed.wizard);
      },
    );
  }
}
