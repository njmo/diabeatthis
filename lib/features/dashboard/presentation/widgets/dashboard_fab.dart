import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/anchored_fab_menu.dart';
import '../../../../common/widgets/fab_action_option.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/logger/logger.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../../activity/data/services/save_activity_action.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_sheet.dart';
import '../../../manual_events/presentation/widgets/manual_event_sheet.dart';
import '../../../meals/data/domain/use_cases/add_meal_use_case.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_activation_guard_provider.dart';
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
    final mealBlockingActivation = ref.watch(anyMealBlockingActivationProvider);
    final quickMealEnabled = mealBlockingActivation.asData?.value == null;

    return AnchoredFabMenu(
      open: open.value,
      onToggle: () => open.value = !open.value,
      onDismiss: () => open.value = false,
      actions: [
        if (open.value) ...[
          FabActionOption(
            icon: Icons.event_note_outlined,
            label: context.lang.manualEventAddStress,
            onTap: () async {
              open.value = false;
              await showManualEventSheet(context);
            },
          ),
          const SizedBox(height: 8),
          FabActionOption(
            icon: Icons.directions_run,
            label: context.lang.dashboardAddActivity,
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
            icon: Icons.local_drink_outlined,
            label: context.lang.dashboardAddLowTreatment,
            onTap: () async {
              open.value = false;
              await showLowTreatmentSheet(context);
            },
          ),
          const SizedBox(height: 8),
          FabActionOption(
            icon: Icons.restaurant,
            label: context.lang.dashboardPlanMeal,
            onTap: () {
              ref.read(mealDraftProvider.notifier).reset();
              context.router.push(routes.AddMealRoute());
              open.value = false;
            },
          ),
          const SizedBox(height: 8),
          FabActionOption(
            icon: Icons.bakery_dining_rounded,
            label: context.lang.dashboardQuickMeal,
            enabled: quickMealEnabled,
            onTap: () async {
              open.value = false;
              final blockingMeal = await ref.refresh(
                currentMealBlockingActivationProvider.future,
              );
              if (blockingMeal != null) {
                return;
              }
              if (!context.mounted) {
                return;
              }
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
                final quickMealDraft = ref.read(mealDraftProvider);
                late final Meal addedMeal;
                try {
                  addedMeal = await ref
                      .read(addMealUseCaseProvider)
                      .call(quickMealDraft);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_addMealErrorMessage(context, e))),
                    );
                  }
                  ref.read(mealDraftProvider.notifier).reset();
                  return;
                }

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
        ],
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
      await saveActivityAction(ref, action);
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
          title: Text(context.lang.dashboardActivityInProgressTitle),
          content: Text(context.lang.dashboardActivityInProgressMessage),
        );
      },
    );
  }

  Future<void> showActivityAddFailedDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.lang.dashboardActivityAddFailedTitle),
          content: Text(context.lang.dashboardActivityAddFailedMessage),
        );
      },
    );
  }
}

String _addMealErrorMessage(BuildContext context, Object error) {
  if (error is ArgumentError && error.message is String) {
    return error.message as String;
  }

  return context.lang.dashboardAddMealFailed;
}
