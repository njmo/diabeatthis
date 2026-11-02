import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_display_name.dart';
import '../../../../../common/widgets/delete_confirmation_dialog.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../data/providers/meal_database_provider.dart';

Future<void> deleteDashboardMeal({
  required BuildContext context,
  required WidgetRef ref,
  required Meal meal,
}) async {
  final confirmed = await showDeleteConfirmationDialog(
    context,
    title: lang.mealDeleteTitle,
    message: lang.mealDeleteMessage(mealDisplayName(meal.name)),
    confirmLabel: lang.mealDeleteConfirm,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(removeMealByIdProvider(meal.id).future);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.mealDeleteSuccess)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.mealDeleteFailed(error))));
    }
  }
}
