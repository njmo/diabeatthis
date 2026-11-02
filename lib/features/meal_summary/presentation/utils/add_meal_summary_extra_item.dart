import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../controllers/meal_summary_controller.dart';
import 'meal_summary_extra_item_portion_resolver.dart';

Future<bool> addMealSummaryExtraItem({
  required BuildContext context,
  required WidgetRef ref,
  required int mealId,
}) async {
  final item = await showAddMealIngredientSheet(context: context, ref: ref);
  if (item == null || !context.mounted) return false;
  final resolved = await resolveMealSummaryExtraItemPortionAmount(
    item: item,
    loadPortionAmount: () => ref.read(
      gramsPerPortionProvider(
        item.ingredient,
        item.ingredientPortion.portion,
      ).future,
    ),
  );
  if (!context.mounted) return false;
  ref
      .read(mealSummaryControllerProvider(mealId).notifier)
      .addExtraItem(resolved);
  return true;
}
