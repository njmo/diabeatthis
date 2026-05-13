import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/platform/aaps_launcher.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
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

  final result = await ref.read(aapsLauncherProvider).openAaps();

  if (result == AapsLaunchResult.opened) {
    await showAapsBolusSuggestionNotification(
      ref: ref,
      meal: meal,
      status: status,
    );
    return;
  }

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Nie udało się otworzyć AAPS. Otwórz aplikację ręcznie.'),
    ),
  );
}

Future<void> showAapsBolusSuggestionNotification({
  required WidgetRef ref,
  required Meal meal,
  required String status,
}) async {
  try {
    final advice = await ref.read(getMealAdviceProvider(meal).future);
    final extendedCarbs = advice?.extendedCarbs;
    final carbs = await _carbsForAaps(ref, meal);
    final event = AapsBolusSuggestionNotificationEvent(
      mealId: meal.id,
      mealName: meal.name,
      carbs: carbs,
      status: status,
      waitMinutes: advice?.wait?.recommendedMinutes,
      extendedCarbs: extendedCarbs?.grams.round() ?? 0,
      extendedCarbsDeliveryMode:
          extendedCarbs?.scheduleSettings.deliveryMode ??
          ExtendedCarbsDeliveryMode.extendedCarbs,
      extendedCarbsDelayMinutes:
          extendedCarbs?.scheduleSettings.delayMinutes ?? 45,
      extendedCarbsDurationMinutes:
          extendedCarbs?.scheduleSettings.durationMinutes ?? 120,
    );

    await ref.read(notificationsControllerUiProvider).show(event);
  } catch (e, st) {
    Log.e(
      'MealStatusDialogResultHandler',
      'Could not show AAPS bolus suggestion notification',
      error: e,
      stackTrace: st,
    );
  }
}

Future<int> _carbsForAaps(WidgetRef ref, Meal meal) async {
  final mealCarbs = meal.carbs;
  if (mealCarbs != null && mealCarbs > 0) {
    return mealCarbs;
  }

  final db = ref.read(databaseProvider);
  final summary = await db.ingredientDao.totalsForMeal(meal.id);
  return summary?.netCarbsGrams.round() ?? 0;
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
    return 'Wpisz ${result.roundedTotalNetCarbs}g w AAPS';
  }

  if (result.roundedAddedNetCarbs <= 0) {
    return 'Dokładka zapisana';
  }

  return 'Dodaj +${result.roundedAddedNetCarbs}g w AAPS';
}

String _addOnMessage(String? mealStatus, MealAddOnMultiplierResult result) {
  if (mealStatus == 'eating-then-bolus') {
    return 'W AAPS wpisz ${result.roundedTotalNetCarbs}g węglowodanów za cały zjedzony posiłek. AAPS policzy insulinę według profilu.';
  }

  if (result.roundedAddedNetCarbs <= 0) {
    return 'Zapisano dokładkę. Nie wyszła dodatkowa ilość węglowodanów do wpisania w AAPS.';
  }

  return 'Dokładka dodała około +${result.roundedAddedNetCarbs}g węglowodanów. W AAPS wpisz tę wartość jako dodatkowe węglowodany.';
}

bool shouldOpenSummaryAfterMealStatusUpdate(String status) {
  return status == 'eaten' || status == 'eaten-bolused';
}

bool shouldOpenAapsAfterMealStatusUpdate(String status) {
  return status == 'bolused-eating' || status == 'bolused-waiting';
}
