import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/domain/model/meal.dart';
import '../../../meal_summary/domain/use_cases/apply_meal_add_on_multiplier_use_case.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
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
      await ref.read(updateMealProvider(meal, status).future);
      if (context.mounted &&
          openSummaryAfterEaten &&
          (status == 'eaten' || status == 'eaten-bolused')) {
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
      title: Text('${result.roundedTotalNetCarbs}g węglowodanów razem'),
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

String _addOnMessage(String? mealStatus, MealAddOnMultiplierResult result) {
  if (mealStatus == 'eating-then-bolus') {
    return 'W AAPS wpisz ${result.roundedTotalNetCarbs}g węglowodanów za cały zjedzony posiłek. AAPS policzy insulinę według profilu.';
  }

  if (result.roundedAddedNetCarbs <= 0) {
    return 'Zapisano dokładkę. Nie wyszła dodatkowa ilość węglowodanów do wpisania w AAPS.';
  }

  return 'Dokładka dodała około +${result.roundedAddedNetCarbs}g węglowodanów. W AAPS wpisz tę wartość jako dodatkowe węglowodany.';
}
