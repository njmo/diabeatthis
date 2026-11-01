import 'package:flutter/material.dart';

import '../../../../core/domain/model/meal.dart';
import '../../data/meal_dialog_state.dart';
import '../widgets/meal_status_dialog.dart';
import '../widgets/meal_status_dialog_result.dart';

Future<MealStatusDialogResult?> showMealStatusDialog({
  required BuildContext context,
  required Meal meal,
}) {
  final dialog = MealStatusDialog(meal: meal);
  if (dialog.getStep() == MealDialogStep.choose) {
    return showModalBottomSheet<MealStatusDialogResult>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => dialog,
    );
  }
  return showDialog<MealStatusDialogResult>(
    context: context,
    builder: (_) => dialog,
  );
}
