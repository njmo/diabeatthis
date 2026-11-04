import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/providers/meal_draft_provider.dart';
import 'add_meal_ingredient.dart';

Future<void> addIngredientToMealDraft(
  BuildContext context,
  WidgetRef ref,
) async {
  final mealIngredient = await showAddMealIngredientSheet(
    context: context,
    ref: ref,
  );
  if (mealIngredient != null && context.mounted) {
    final added = ref
        .read(mealDraftProvider.notifier)
        .addMealIngredient(mealIngredient);
    if (!added && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.mealIngredientAlreadyOnList)),
      );
    }
  }
}
