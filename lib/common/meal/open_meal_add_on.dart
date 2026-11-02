import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/model/meal.dart';
import '../../features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../features/dashboard/presentation/widgets/meal_add_on_mode_dialog.dart';
import '../../features/dashboard/presentation/widgets/meal_status_dialog_result.dart';

Future<void> openMealAddOn({
  required BuildContext context,
  required WidgetRef ref,
  required Meal meal,
}) async {
  final choice = await showDialog<MealAddOnChoice>(
    context: context,
    builder: (_) => const MealAddOnModeDialog(),
  );
  if (choice == null || !context.mounted) return;
  await handleMealAddOnChoice(
    context: context,
    ref: ref,
    meal: meal,
    choice: choice,
  );
}
