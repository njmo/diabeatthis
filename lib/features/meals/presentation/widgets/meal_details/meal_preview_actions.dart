import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/open_meal_completion.dart';
import '../../../../../core/domain/model/meal_status_flow.dart';
import '../../../../dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../../../dashboard/presentation/utils/show_meal_status_dialog.dart';
import '../../../data/models/meal_details_data.dart';

class MealPreviewActions extends ConsumerWidget {
  final MealRecordData meal;

  const MealPreviewActions({super.key, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canComplete =
        mealStatusesStartingEating.contains(meal.status) ||
        meal.status == 'eating-extra' ||
        mealStatusReadyToSummarize(meal.status);
    final canOpen =
        meal.status == 'planned' ||
        mealStatusBlocksAnotherMealActivation(meal.status);
    if (!canComplete && !canOpen) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(
        onPressed: () async {
          if (canComplete) {
            openMealCompletion(context, mealId: meal.id);
            return;
          }
          final treatment = meal.toDomainTreatment();
          final result = await showMealStatusDialog(
            context: context,
            meal: treatment,
          );
          if (result != null && context.mounted) {
            await handleMealStatusDialogResult(
              context: context,
              ref: ref,
              meal: treatment,
              result: result,
            );
          }
        },
        child: Text(
          canComplete
              ? context.lang.mealStatusAte
              : context.lang.mealPreviewActions,
        ),
      ),
    );
  }
}
