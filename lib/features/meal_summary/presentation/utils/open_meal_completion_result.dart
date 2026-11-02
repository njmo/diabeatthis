import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../domain/use_cases/complete_meal_use_case.dart';
import 'open_meal_summary_aaps_suggestion.dart';

/// Runs the saved instruction through the shared notification-before-AAPS path.
Future<void> openMealCompletionResult({
  required BuildContext context,
  required WidgetRef ref,
  required MealCompletionResult result,
}) async {
  if (result.requiresBolus) {
    final pendingCarbs = result.aapsCarbs;
    await openAapsAfterBolusStatusUpdateIfNeeded(
      context: context,
      ref: ref,
      meal: result.meal.copyWith(
        carbs: pendingCarbs?.carbs ?? result.consumedCarbs,
      ),
      status: 'waiting-for-bolus',
      consumedCarbs: pendingCarbs?.carbs ?? result.consumedCarbs,
      consumedExtendedCarbs:
          pendingCarbs?.extendedCarbs ?? result.consumedExtendedCarbs,
    );
  } else if (result.aapsCarbs != null) {
    await openMealAapsCarbsSuggestion(
      context: context,
      ref: ref,
      mealId: result.meal.id,
      aapsCarbs: result.aapsCarbs!,
    );
  }
}
