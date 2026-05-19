import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/widgets/fab_action_option.dart';
import '../../../../core/logger/logger.dart';
import '../../../activity/data/drafts/activity_log_draft.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../../meals/data/domain/use_cases/add_meal_use_case.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../utils/meal_status_dialog_result_handler.dart';
import 'dashboard_activity_sheet.dart';
import 'meal_status_dialog.dart';
import 'meal_status_dialog_result.dart';

class DashboardFAB extends HookConsumerWidget with Logging {
  const DashboardFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = useState(false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open.value) ...[
          FabActionOption(
            icon: Icons.directions_run,
            label: 'Dodaj aktywność',
            onTap: () async {
              open.value = false;
              final action =
                  await showModalBottomSheet<DashboardActivityAction>(
                    context: context,
                    useRootNavigator: false,
                    isScrollControlled: true,
                    builder: (_) => const DashboardActivitySheet(),
                  );
              if (action == null) return;
              if (!context.mounted) return;

              await _saveActivityLog(context, ref, action);
            },
          ),
          const SizedBox(height: 8),
          FabActionOption(
            icon: Icons.restaurant,
            label: 'Zaplanuj posiłek',
            onTap: () {
              ref.read(mealDraftProvider.notifier).reset();
              context.router.push(routes.AddMealRoute());
              open.value = false;
            },
          ),
          const SizedBox(height: 8),
          FabActionOption(
            icon: Icons.bakery_dining_rounded,
            label: 'Zjedz coś na szybko',
            onTap: () async {
              open.value = false;
              ref.read(mealDraftProvider.notifier).reset();
              final mealIngredient =
                  await showModalBottomSheet<MealIngredientsDraft>(
                    context: context,
                    useRootNavigator: false,
                    isScrollControlled: true,
                    builder: (_) => AddMealIngredient(),
                  );
              if (mealIngredient != null) {
                final draft = ref.read(mealDraftProvider.notifier);
                draft.addMealIngredient(mealIngredient);
                draft.setName("QM: ${mealIngredient.ingredient.name}");
                final addedMeal = await ref
                    .read(addMealUseCaseProvider)
                    .call(ref.read(mealDraftProvider));

                if (!context.mounted) {
                  return;
                }

                final result = await showDialog<MealStatusDialogResult?>(
                  barrierDismissible: true,
                  context: context,
                  builder: (context) => MealStatusDialog(meal: addedMeal),
                );
                if (result != null && context.mounted) {
                  await handleMealStatusDialogResult(
                    context: context,
                    ref: ref,
                    meal: addedMeal,
                    result: result,
                    openSummaryAfterEaten: false,
                  );
                }
                ref.read(mealDraftProvider.notifier).reset();
              }
            },
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: () => open.value = !open.value,
          child: Icon(open.value ? Icons.close : Icons.add),
        ),
      ],
    );
  }

  Future<void> _saveActivityLog(
    BuildContext context,
    WidgetRef ref,
    DashboardActivityAction action,
  ) async {
    try {
      logI('Adding activity log');
      await ref.read(
        insertActivityLogProvider(
          ActivityLogDraft(
            activity: action.activity,
            startedAt: action.startedAt,
          ),
        ).future,
      );
      ref.invalidate(getPendingActivityProvider);
    } catch (e) {
      if (context.mounted) {
        await showActivityAddFailedDialog(context);
      }
    }
  }

  Future<void> showActivityInProgressDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Aktywność w toku'),
          content: const Text(
            'Jedna aktywność jest już w trakcie.\n\n'
            'Nie można rozpocząć nowej, dopóki obecna nie zostanie zakończona.',
          ),
        );
      },
    );
  }

  Future<void> showActivityAddFailedDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Problem z dodaniem aktywności'),
          content: const Text(
            'Taka aktywność już istnieje lub parametry nie są podane prawidłowo.\n'
            'Pamiętaj: pre i post muszą być <100 i >0.',
          ),
        );
      },
    );
  }
}
