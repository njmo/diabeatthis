import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/open_meal_completion.dart';
import '../../../../../common/meal_advisor/presentation/remote/child_meal_decision_meal_action.dart';
import '../../../../../common/monitoring/meal_wait_status.dart';
import '../../../../../core/domain/model/meal_status_flow.dart';
import '../../../../dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../../../dashboard/presentation/utils/show_meal_status_dialog.dart';
import '../../../data/models/meal_details_data.dart';
import '../../utils/start_eating_without_extended_carbs.dart';

/// The meal's next step, named after what it does.
class MealPreviewActions extends ConsumerWidget {
  final MealRecordData meal;

  const MealPreviewActions({super.key, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = meal.status;
    final canComplete =
        mealStatusesStartingEating.contains(status) ||
        status == 'eating-extra' ||
        mealStatusReadyToSummarize(status);
    final canOpen =
        status == 'planned' || mealStatusBlocksAnotherMealActivation(status);
    if (!canComplete && !canOpen) return const SizedBox.shrink();
    final wait = status == 'bolused-waiting'
        ? ref.watch(mealWaitStatusProvider).value
        : null;
    final waitsForExtendedCarbs = mealWaitHeldByExtendedCarbs(
      wait,
      meal.id,
      clock.now(),
    );

    Future<void> openStatusDialog() async {
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
    }

    Future<void> openCalculator() async {
      try {
        await openAapsAfterBolusStatusUpdateIfNeeded(
          context: context,
          ref: ref,
          meal: meal.toDomainTreatment(),
          status: 'waiting-for-bolus',
        );
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.lang.aapsOpenFailed)));
        }
      }
    }

    final lang = context.lang;
    final (String label, Future<void> Function() action) = canComplete
        ? (
            lang.mealStatusAte,
            () async => openMealCompletion(context, mealId: meal.id),
          )
        : waitsForExtendedCarbs
        ? (
            lang.mealSkipExtendedCarbsConfirm,
            () => confirmStartEatingWithoutExtendedCarbs(
              context: context,
              ref: ref,
              mealId: meal.id,
            ),
          )
        : switch (status) {
            'waiting-for-bolus' => (
              lang.mealProgressOpenCalculator,
              openCalculator,
            ),
            'bolused-waiting' => (lang.mealStatusStartEating, openStatusDialog),
            'eating-then-bolus' => (
              lang.mealStatusDeliverBolus,
              openStatusDialog,
            ),
            _ => (lang.mealPreviewActions, openStatusDialog),
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == 'planned') ChildMealDecisionMealAction(mealId: meal.id),
        FilledButton(onPressed: action, child: Text(label)),
      ],
    );
  }
}
