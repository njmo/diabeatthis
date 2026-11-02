import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/meal/meal_add_on_bolus_context.dart';
import '../../../../common/meal/meal_extended_carbs.dart';
import '../../../../common/meal/open_meal_add_on_editor.dart';
import '../../../../common/meal/open_meal_completion.dart';
import '../../../../common/platform/aaps_suggestion_prompt.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../meals/data/domain/use_cases/complete_bolus_wait_use_case.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
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
        await ref.read(completeBolusWaitUseCaseProvider).call(meal);
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
      consumedCarbs = (totals?.netCarbsGrams ?? 0).ceil();
      consumedExtendedCarbs = mealExtendedCarbsFromMacros(totals);
    }
  }
  final extendedCarbs = advice?.extendedCarbs;
  final extendedCarbsGrams = consumedExtendedCarbs ?? extendedCarbs?.grams ?? 0;
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
    final consumedCarbs = (consumedSummary?.netCarbsGrams ?? 0).ceil();
    if (consumedCarbs > 0) {
      return consumedCarbs;
    }
  }

  final summary = await db.ingredientDao.totalsForMeal(meal.id);
  return (summary?.netCarbsGrams ?? 0).ceil();
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
