import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/l10n/language.dart';
import '../../../../common/platform/aaps_suggestion_prompt.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../meal_summary/domain/use_cases/apply_meal_add_on_multiplier_use_case.dart';
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
    case MealStatusUpdateResult(:final status):
      if (meal.status == 'bolused-waiting' && status == 'waited-eating') {
        await ref.read(completeBolusWaitUseCaseProvider).call(meal);
        return;
      }

      await ref.read(updateMealProvider(meal, status).future);
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
        context.router.push(routes.MealSummaryRoute(mealId: meal.id));
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
}) async {
  if (!shouldOpenAapsAfterMealStatusUpdate(status)) {
    return;
  }

  final event = await _aapsSuggestionNotificationEvent(ref, meal, status);
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
  String status,
) async {
  final advice = await ref.read(getMealAdviceProvider(meal).future);
  final extendedCarbs = advice?.extendedCarbs;
  final extendedCarbsGrams = extendedCarbs?.grams ?? 0;

  if (!shouldCreateAapsSuggestionForMealStatus(
    status,
    extendedCarbsGrams: extendedCarbsGrams,
  )) {
    return null;
  }

  final carbs = status == 'eating-then-bolus'
      ? 0
      : await _carbsForAaps(ref, meal, status);
  return AapsBolusSuggestionNotificationEvent(
    carbs: carbs,
    extendedCarbs: extendedCarbsGrams,
    extendedCarbsDeliveryMode: extendedCarbsGrams > 0
        ? extendedCarbs?.scheduleSettings.deliveryMode
        : null,
    extendedCarbsDelayMinutes: extendedCarbsGrams > 0
        ? extendedCarbs?.scheduleSettings.delayMinutes
        : null,
    extendedCarbsDurationMinutes: extendedCarbsGrams > 0
        ? extendedCarbs?.scheduleSettings.durationMinutes
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
  final multiplier = choice.multiplier;

  if (multiplier == null) {
    if (context.mounted) {
      context.router.push(routes.MealSummaryRoute(mealId: meal.id));
    }
    return;
  }

  final result = await ref
      .read(applyMealAddOnMultiplierUseCaseProvider)
      .call(
        mealId: meal.id,
        currentMealStatus: meal.status,
        multiplier: multiplier,
      );

  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_addOnTitle(meal.status, result)),
      content: Text(_addOnMessage(meal.status, result)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String _addOnTitle(String? mealStatus, MealAddOnMultiplierResult result) {
  if (mealStatus == 'eating-then-bolus') {
    return lang.mealAddOnResultTotalTitle(result.roundedTotalNetCarbs);
  }

  if (result.roundedAddedNetCarbs <= 0) {
    return lang.mealAddOnResultSavedTitle;
  }

  return lang.mealAddOnResultAddedTitle(result.roundedAddedNetCarbs);
}

String _addOnMessage(String? mealStatus, MealAddOnMultiplierResult result) {
  if (mealStatus == 'eating-then-bolus') {
    return lang.mealAddOnResultTotalMessage(result.roundedTotalNetCarbs);
  }

  if (result.roundedAddedNetCarbs <= 0) {
    return lang.mealAddOnResultSavedMessage;
  }

  return lang.mealAddOnResultAddedMessage(result.roundedAddedNetCarbs);
}

bool shouldOpenSummaryAfterMealStatusUpdate(String status) {
  return status == 'eaten' || status == 'eaten-bolused';
}

bool shouldOpenAapsAfterMealStatusUpdate(String status) {
  return status == 'eating-then-bolus' ||
      status == 'waiting-for-bolus' ||
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

  if (status == 'eating-then-bolus') {
    return extendedCarbsGrams > 0;
  }

  return true;
}
