import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../../../../common/meal/meal_add_on_bolus_context.dart';
import '../../../../../common/meal/meal_add_on_bolus_progress.dart';
import '../../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../../common/notifications/meal_notification_cancellation.dart';
import '../../../../../common/notifications/scoped_notification_cancellation.dart';
import '../../../../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../../../core/notifications/domain/models/notification_event_type.dart';
import '../../../../../core/notifications/domain/models/notification_key.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../../features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import '../../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../../providers/latest_bolus_wizard_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'bolus_reminder_helper.dart';
import 'wait_for_meal_bolus_delivery.dart';

/// Returns null for legacy meals, which retain their original monitor path.
class MealAddOnBolusWaiter {
  const MealAddOnBolusWaiter();

  Future<bool?> call(
    RuntimeContext runtime,
    MealMonitorContext mealContext, {
    required bool remindImmediately,
  }) async {
    if (!runtime.container.exists(databaseProvider)) return null;
    final db = runtime.container.read(databaseProvider);
    if (!db.hasOpened) return null;
    final mealId = mealContext.activeMeal!.id;
    var context = await readMealAddOnBolusContext(db, mealId);
    if (context == null) return null;
    final notifications = runtime.container.read(
      notificationsControllerForegroundProvider,
    );
    final ignoredWizardKeys = <String>{};
    var allowGracePeriod = !remindImmediately;
    while (true) {
      mealContext.throwIfStopped(runtime);
      final previousCoverage = context?.coveredCarbs;
      context = await reconcileMealAddOnBolusProgress(db, mealId);
      mealContext.throwIfStopped(runtime);
      if (context == null) return false;
      if (previousCoverage != context.coveredCarbs) {
        await refreshInstruction(runtime, mealContext, context);
      }
      final cached = runtime.container.read(latestBolusWizardProvider);
      if (cached != null &&
          (context.acceptedWizardKeys.contains(mealBolusWizardKey(cached)) ||
              context.acceptedWizardKeys.contains(
                'at:${cached.createdAt.millisecondsSinceEpoch}',
              ))) {
        consumeBolusWizard(runtime.container, cached);
      }
      if (!context.awaitingBolus) return true;
      final request = context;
      final pendingExtendedCarbs = request.extendedCarbsConfirmed
          ? 0
          : request.requestedExtendedCarbs;
      bool accepts(BolusWizard wizard) =>
          mealAddOnAcceptsWizard(request, wizard) &&
          !ignoredWizardKeys.contains(mealBolusWizardKey(wizard));
      Future<void> record(BolusWizard wizard) async {
        mealContext.throwIfStopped(runtime);
        final submission = await const WaitForMealBolusDelivery()(
          runtime,
          mealContext,
          wizard,
          acceptsWizard: accepts,
        );
        mealContext.throwIfStopped(runtime);
        final accepted = await acceptMealAddOnBolus(
          db,
          mealId,
          submission.wizard,
          requestedAt: request.requestedAt,
        );
        mealContext.throwIfStopped(runtime);
        if (accepted == null) {
          ignoredWizardKeys.add(mealBolusWizardKey(submission.wizard));
          return;
        }
        consumeBolusWizard(runtime.container, submission.wizard);
        await refreshInstruction(runtime, mealContext, accepted);
      }

      var latest = runtime.container.read(latestBolusWizardProvider);
      if (latest == null || !accepts(latest)) {
        final saved =
            await (db.select(db.bolusWizard)
                  ..where(
                    (row) => row.createdAt.isBiggerOrEqualValue(
                      request.bolusWindowStartedAt.millisecondsSinceEpoch,
                    ),
                  )
                  ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
                .get();
        latest = saved.map((row) => row.toDomain()).where(accepts).firstOrNull;
      }
      mealContext.throwIfStopped(runtime);
      if (latest != null && accepts(latest)) {
        await record(latest);
        await notifications.cancelMealNotifications(mealId);
        continue;
      }
      if (allowGracePeriod) {
        allowGracePeriod = false;
        final remaining = request.requestedAt
            .add(const Duration(minutes: 10))
            .difference(clock.now());
        final event = remaining <= Duration.zero
            ? null
            : await runtime.waitForEventWithTimeoutOrNull<
                TreatmentAvailableEvent<BolusWizard>
              >(remaining, predicate: (event) => accepts(event.data));
        if (event != null) {
          await record(event.data);
          await notifications.cancelMealNotifications(mealId);
          continue;
        }
      }
      var schedule = const ExtendedCarbsScheduleSettings.defaults();
      if (pendingExtendedCarbs > 0) {
        schedule = MealAdvisor(
          config: MealAdvisorConfig(
            extendedCarbsScheduleSettings: await runtime.container.read(
              extendedCarbsScheduleSettingsProvider.future,
            ),
          ),
        ).getPostMealExtendedCarbsScheduleSettings();
      }
      final accepted = await BolusReminderHelper().remindUntilBolusRecorded(
        runtime,
        notifications,
        mealId,
        carbs: request.requestedCarbs,
        extendedCarbs: pendingExtendedCarbs,
        extendedCarbsAreAdditional: true,
        extendedCarbsDeliveryMode: schedule.deliveryMode,
        extendedCarbsDelayMinutes: schedule.delayMinutes,
        extendedCarbsDurationMinutes: schedule.durationMinutes,
        isAddOn: false,
        acceptsBolus: accepts,
        ensureActive: () => mealContext.throwIfStopped(runtime),
        onBolusRecorded: record,
      );
      if (!accepted) return false;
    }
  }

  Future<void> refreshInstruction(
    RuntimeContext runtime,
    MealMonitorContext mealContext,
    MealAddOnBolusContext request,
  ) async {
    final mealId = mealContext.activeMeal!.id;
    final pendingExtendedCarbs = request.extendedCarbsConfirmed
        ? 0
        : request.requestedExtendedCarbs;
    try {
      mealContext.throwIfStopped(runtime);
      final before = await readMealAddOnBolusContext(
        runtime.container.read(databaseProvider),
        mealId,
      );
      if (before?.encode() != request.encode()) return;
      mealContext.throwIfStopped(runtime);
      final notifications = runtime.container.read(
        notificationsControllerForegroundProvider,
      );
      await notifications.cancelNotification(
        NotificationKey(
          type: NotificationEventType.aapsBolusSuggestion,
          entityId: mealId,
        ),
      );
      mealContext.throwIfStopped(runtime);
      if (request.requestedCarbs == 0 && pendingExtendedCarbs == 0) {
        return;
      }
      var schedule = const ExtendedCarbsScheduleSettings.defaults();
      if (pendingExtendedCarbs > 0) {
        schedule = MealAdvisor(
          config: MealAdvisorConfig(
            extendedCarbsScheduleSettings: await runtime.container.read(
              extendedCarbsScheduleSettingsProvider.future,
            ),
          ),
        ).getPostMealExtendedCarbsScheduleSettings();
      }
      mealContext.throwIfStopped(runtime);
      final current = await readMealAddOnBolusContext(
        runtime.container.read(databaseProvider),
        mealId,
      );
      if (current?.encode() != request.encode()) return;
      mealContext.throwIfStopped(runtime);
      await notifications.show(
        AapsBolusSuggestionNotificationEvent(
          mealId: mealId,
          carbs: request.requestedCarbs,
          extendedCarbs: pendingExtendedCarbs,
          extendedCarbsAreAdditional: true,
          extendedCarbsDeliveryMode: schedule.deliveryMode,
          extendedCarbsDelayMinutes: schedule.delayMinutes,
          extendedCarbsDurationMinutes: schedule.durationMinutes,
        ),
      );
    } catch (error, stackTrace) {
      mealContext.throwIfStopped(runtime);
      Log.e(
        'MealAddOnBolusWaiter',
        'Could not refresh the remaining carbohydrate instruction',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
