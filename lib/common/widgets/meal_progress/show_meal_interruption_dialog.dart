import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/meal.dart';
import '../../../core/domain/model/meal_status_flow.dart';
import '../../../features/meals/data/domain/use_cases/interrupt_meal_use_case.dart';
import '../../l10n/language.dart';
import '../../meal/open_meal_completion.dart';
import 'meal_interruption_dialog.dart';

Future<void> showMealInterruptionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Meal meal,
}) async {
  final choice = await showDialog<MealInterruptionChoice>(
    context: context,
    builder: (_) => MealInterruptionDialog(
      canFinishEating:
          mealStatusesStartingEating.contains(meal.status) ||
          meal.status == 'eating-extra',
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == MealInterruptionChoice.finishEating) {
    await openMealCompletion(context, mealId: meal.id);
    return;
  }
  try {
    final stopped = await ref.read(interruptMealUseCaseProvider)(
      meal.id,
      expectedStatus: meal.status,
    );
    if (!stopped && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.mealInterruptionChanged)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.mealInterruptionFailed)),
      );
    }
  }
}
