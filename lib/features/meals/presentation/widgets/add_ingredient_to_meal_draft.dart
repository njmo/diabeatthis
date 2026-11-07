import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/planning/meal_form_actions.dart';
import '../../data/providers/meal_draft_provider.dart';

Future<void> addIngredientToMealDraft(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final mealIngredient = await ref
        .read(mealFormActionsProvider)
        .pickIngredient(context, ref);
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
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(mealFormActionsProvider).failureMessage(context, error),
          ),
        ),
      );
    }
  }
}
