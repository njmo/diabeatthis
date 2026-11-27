import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_add_on_bolus_context.dart';
import '../../../../common/meal/meal_extended_carbs.dart';
import '../../../../common/meal/open_meal_add_on_editor.dart';
import '../../../../common/meal/open_meal_completion.dart';
import '../../../../common/monitoring/meal_wait_status.dart';
import '../../../../common/notifications/meal_notification_cancellation.dart';
import '../../../../common/nutrition/stable_macro_ceil.dart';
import '../../../../common/platform/aaps_suggestion_prompt.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../../core/notifications/handlers/notification_response_handler.dart';
import '../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../meal_advisor/data/providers/get_meal_activity_advice_use_case_provider.dart';
import '../../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../meals/presentation/utils/start_eating_without_extended_carbs.dart';
import '../../data/providers/meal_advisor_result_provider.dart';
import '../widgets/meal_status_dialog_result.dart';

Future<void> handleMealStatusDialogResult({
  required BuildContext context,
  required WidgetRef ref,
  required Meal meal,
  required MealStatusDialogResult result,
  bool openSummaryAfterEaten = true,
}) async {
  switch (result) {
    case MealStatusUpdateResult(:final status, :final alreadySaved):
      final finishingEating =
          (mealStatusesStartingEating.contains(meal.status) ||
              meal.status == 'eating-extra') &&
          (mealStatusReadyToSummarize(status) ||
              (meal.status == 'eating-then-bolus' &&
                  status == 'waiting-for-bolus'));
      if (finishingEating && !alreadySaved) {
        await openMealCompletion(context, mealId: meal.id);
        return;
      }
      if (!alreadySaved &&
          meal.status == 'bolused-waiting' &&
          status == 'waited-eating') {
        final wait = await readMealWaitStatus();
        if (wait?.mealId == meal.id && wait!.waitingForExtendedCarbs) {
          if (context.mounted) {
            await confirmStartEatingWithoutExtendedCarbs(
              context: context,
              ref: ref,
              mealId: meal.id,
            );
          }
          return;
        }
        if (!await requestMealStartEating(meal.id) && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(lang.uiMonitoringUnavailable)));
        }
        return;
      }

      if (!alreadySaved && status == 'skipped') {
        final notifications = ref.read(notificationsControllerUiProvider);
        final saved = await ref
            .read(databaseProvider)
            .mealDao
            .tryUpdateMealStatus(meal.id, status);
        if (saved) {
          try {
            await notifications.cancelMealNotifications(
              meal.id,
              includeTargetConsent: true,
              includeBolusInstructions: true,
            );
          } catch (error, stackTrace) {
            Log.e(
              'MealStatusDialog',
              'Could not clear notifications for skipped meal ${meal.id}',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        return;
      }
      if (!alreadySaved) {
        await ref.read(updateMealProvider(meal, status).future);
      }
      if (!context.mounted) {
        return;
      }

      await openAapsAfterBolusStatusUpdateIfNeeded(
        context: context,
        ref: ref,
        meal: meal,
        status: status,
      );

      if (context.mounted &&
          openSummaryAfterEaten &&
          shouldOpenSummaryAfterMealStatusUpdate(status)) {
        await openMealCompletion(context, mealId: meal.id);
      }
    case MealStatusAddOnResult(:final choice):
      await handleMealAddOnChoice(
        context: context,
        ref: ref,
        meal: meal,
        choice: choice,
      );
  }
}

Future<void> openAapsAfterBolusStatusUpdateIfNeeded({
  required BuildContext context,
  required WidgetRef ref,
  required Meal meal,
  required String status,
  int? consumedCarbs,
  int? consumedExtendedCarbs,
}) async {
  if (!shouldOpenAapsAfterMealStatusUpdate(status)) {
    return;
  }

  final event = await _aapsSuggestionNotificationEvent(
    ref,
    meal,
    status,
    consumedCarbs: consumedCarbs,
    consumedExtendedCarbs: consumedExtendedCarbs,
  );
  if (event == null) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  await openAapsWithSuggestionNotification(
    context: context,
    ref: ref,
    event: event,
  );
}

Future<AapsBolusSuggestionNotificationEvent?> _aapsSuggestionNotificationEvent(
  WidgetRef ref,
  Meal meal,
  String status, {
  int? consumedCarbs,
  int? consumedExtendedCarbs,
}) async {
  final advice = await ref.read(getMealAdviceProvider(meal).future);
  if (status == 'waiting-for-bolus' &&
      consumedCarbs == null &&
      consumedExtendedCarbs == null) {
    final db = ref.read(databaseProvider);
    final persisted = await db.mealDao.getMealById(meal.id);
    final pending = MealAddOnBolusContext.decode(persisted?.addOnBolusContext);
    if (pending != null) {
      if (!pending.awaitingBolus) return null;
      consumedCarbs = pending.requestedCarbs;
      consumedExtendedCarbs = pending.requestedExtendedCarbs;
    } else if (persisted?.consumptionConfirmedEndedAt != null) {
      final totals = await db.ingredientDao.totalsForMealConsumed(meal.id);
      consumedCarbs = (totals?.netCarbsGrams ?? 0).ceilMacro();
      consumedExtendedCarbs = mealExtendedCarbsFromMacros(totals);
    }
  }
  final extendedCarbs = advice?.extendedCarbs;
  final plannedMacros =
      consumedExtendedCarbs == null &&
          status == 'waiting-for-bolus' &&
          advice?.source == 'caregiver' &&
          extendedCarbs?.shouldSuggest != true
      ? await ref.read(databaseProvider).ingredientDao.totalsForMeal(meal.id)
      : null;
  final extendedCarbsGrams =
      consumedExtendedCarbs ??
      (plannedMacros == null
          ? extendedCarbs?.grams ?? 0
          : mealExtendedCarbsFromMacros(plannedMacros));
  final schedule =
      extendedCarbs?.scheduleSettings ??
      const ExtendedCarbsScheduleSettings.defaults();

  if (!shouldCreateAapsSuggestionForMealStatus(
    status,
    extendedCarbsGrams: extendedCarbsGrams,
  )) {
    return null;
  }

  final carbs = status == 'eating-then-bolus'
      ? 0
      : consumedCarbs ?? await _carbsForAaps(ref, meal, status);
  if (carbs == 0 && extendedCarbsGrams == 0) return null;
  return AapsBolusSuggestionNotificationEvent(
    mealId: meal.id,
    mealName: meal.name,
    activityDoseSuggestion: carbs > 0
        ? await ref.read(getMealActivityAdviceUseCaseProvider)(mealId: meal.id)
        : null,
    carbs: carbs,
    extendedCarbs: extendedCarbsGrams,
    extendedCarbsAreAdditional:
        status == 'waiting-for-bolus' && consumedExtendedCarbs != null,
    extendedCarbsDeliveryMode: extendedCarbsGrams > 0
        ? schedule.deliveryMode
        : null,
    extendedCarbsDelayMinutes: extendedCarbsGrams > 0
        ? schedule.delayMinutes
        : null,
    extendedCarbsDurationMinutes: extendedCarbsGrams > 0
        ? schedule.durationMinutes
        : null,
  );
}

Future<int> _carbsForAaps(WidgetRef ref, Meal meal, String status) async {
  final mealCarbs = meal.carbs;
  if (mealCarbs != null && mealCarbs > 0) {
    return mealCarbs;
  }

  final db = ref.read(databaseProvider);
  if (status == 'eaten-bolused') {
    final consumedSummary = await db.ingredientDao.totalsForMealConsumed(
      meal.id,
    );
    final consumedCarbs = (consumedSummary?.netCarbsGrams ?? 0).ceilMacro();
    if (consumedCarbs > 0) {
      return consumedCarbs;
    }
  }

  final summary = await db.ingredientDao.totalsForMeal(meal.id);
  return (summary?.netCarbsGrams ?? 0).ceilMacro();
}

Future<void> handleMealAddOnChoice({
  required BuildContext context,
  required WidgetRef ref,
  required Meal meal,
  required MealAddOnChoice choice,
}) async {
  if (!context.mounted) return;
  await openMealAddOnEditor(
    context: context,
    ref: ref,
    meal: meal,
    totalMultiplier: choice.multiplier,
  );
}

bool shouldOpenSummaryAfterMealStatusUpdate(String status) {
  return status == 'eaten' || status == 'eaten-bolused';
}

bool shouldOpenAapsAfterMealStatusUpdate(String status) {
  return status == 'waiting-for-bolus' ||
      status == 'bolused-eating' ||
      status == 'bolused-waiting' ||
      status == 'eaten-bolused';
}

bool shouldCreateAapsSuggestionForMealStatus(
  String status, {
  required int extendedCarbsGrams,
}) {
  if (!shouldOpenAapsAfterMealStatusUpdate(status)) {
    return false;
  }

  return true;
}
