import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/model/meal.dart';
import '../../features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import '../../features/meal_summary/presentation/screens/meal_add_on_editor.dart';
import '../../features/meals/data/providers/meal_database_provider.dart';
import '../../features/meals/data/providers/meal_ingredients_list_provider.dart';

Future<void> openMealAddOnEditor({
  required BuildContext context,
  required WidgetRef ref,
  required Meal meal,
  double? totalMultiplier,
}) async {
  ref.invalidate(getMealByIdProvider(meal.id));
  ref.invalidate(getMealIngredientsDraftForMealProvider(meal.id));
  ref.invalidate(mealSummaryControllerProvider(meal.id));
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: MediaQuery.removeViewInsets(
          context: sheetContext,
          removeBottom: true,
          child: MealAddOnEditor(meal: meal, totalMultiplier: totalMultiplier),
        ),
      ),
    ),
  );
  if (context.mounted) ref.invalidate(mealSummaryControllerProvider(meal.id));
}
