import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_display_name.dart';
import '../../../../common/meal/open_meal_add_on.dart';
import '../../../../common/meal/open_meal_completion.dart';
import '../../../../common/widgets/meal_progress/active_meal_progress_card.dart';
import '../../../../common/widgets/meal_progress/meal_progress_section_heading.dart';
import '../../../../common/widgets/meal_progress/show_meal_interruption_dialog.dart';
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../dashboard/data/providers/time_now_provider.dart';
import '../../../dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../../dashboard/presentation/utils/show_meal_status_dialog.dart';
import '../../data/providers/meal_activation_guard_provider.dart';
import '../../data/providers/meal_database_provider.dart';
import 'meal_details/meal_detail_formatters.dart';
import 'meal_progress/active_meal_add_on_bolus_action.dart';
import 'meal_progress/active_meal_steps.dart';
import 'meal_progress/active_meal_wait_footer.dart';
import 'meal_progress/delete_dashboard_meal.dart';
import 'meal_progress/meal_schedule_group.dart';
import 'meal_progress/meal_schedule_labels.dart';
import 'meal_progress/meal_schedule_tile.dart';

class MealListToday extends ConsumerWidget {
  const MealListToday({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals =
        ref.watch(plannedMealsForTodayStreamProvider).asData?.value ??
        const <domain.Meal>[];
    final parentModeEnabled = ref.watch(parentModeProvider);
    final blockingMeal =
        ref.watch(anyMealBlockingActivationProvider).asData?.value ??
        firstMealBlockingActivation(meals);
    final now = ref.watch(timeNowProvider).asData?.value ?? clock.now();
    // Keep a previous day's active meal reachable even while the list reloads.
    final visibleMeals = [
      if (blockingMeal != null &&
          !meals.any((meal) => meal.id == blockingMeal.id))
        blockingMeal,
      ...meals,
    ];
    final activeMeals = visibleMeals.where(
      (meal) => mealStatusBlocksAnotherMealActivation(meal.status),
    );
    final summaryMeals = visibleMeals.where(
      (meal) => mealStatusReadyToSummarize(meal.status),
    );
    final groups = mealScheduleGroups(visibleMeals);

    Future<void> openExistingActions(domain.Meal meal) async {
      final result = await showMealStatusDialog(context: context, meal: meal);
      if (result != null && context.mounted) {
        await handleMealStatusDialogResult(
          context: context,
          ref: ref,
          meal: meal,
          result: result,
        );
      }
    }

    VoidCallback? deleteAction(domain.Meal meal) => parentModeEnabled
        ? () => deleteDashboardMeal(context: context, ref: ref, meal: meal)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeMeals.isNotEmpty)
            MealProgressSectionHeading(title: lang.mealProgressCurrent),
          for (final meal in activeMeals)
            ActiveMealProgressCard(
              key: ValueKey('active-meal-${meal.id}'),
              name: mealDisplayName(meal.name),
              quickMeal: isQuickMealName(meal.name),
              status: mealStatusLabel(meal.status ?? 'planned'),
              schedule: mealScheduleLabel(context, meal.plannedAt, now),
              steps: ActiveMealSteps(meal: meal),
              progressAction: meal.status == 'eating-extra'
                  ? ActiveMealAddOnBolusAction(mealId: meal.id)
                  : null,
              actionLabel: meal.status == 'bolused-waiting'
                  ? lang.mealStatusStartEating
                  : meal.status == 'waiting-for-bolus'
                  ? lang.mealProgressOpenCalculator
                  : lang.mealStatusAte,
              onAction: () async {
                if (mealStatusesStartingEating.contains(meal.status) ||
                    meal.status == 'eating-extra') {
                  openMealCompletion(context, mealId: meal.id);
                } else if (meal.status == 'waiting-for-bolus') {
                  try {
                    await openAapsAfterBolusStatusUpdateIfNeeded(
                      context: context,
                      ref: ref,
                      meal: meal,
                      status: 'waiting-for-bolus',
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(lang.aapsOpenFailed)),
                      );
                    }
                  }
                } else {
                  openExistingActions(meal);
                }
              },
              addFoodLabel: lang.mealAddOnAction,
              onAddFood: mealStatusesStartingEating.contains(meal.status)
                  ? () => openMealAddOn(context: context, ref: ref, meal: meal)
                  : null,
              onInterrupt: () => showMealInterruptionDialog(
                context: context,
                ref: ref,
                meal: meal,
              ),
              onDelete: deleteAction(meal),
              footer: meal.status == 'bolused-waiting'
                  ? ActiveMealWaitFooter(meal: meal)
                  : null,
            ),
          if (summaryMeals.isNotEmpty)
            MealProgressSectionHeading(title: lang.mealProgressToSummarize),
          for (final meal in summaryMeals)
            MealScheduleTile(
              meal: meal,
              enabled: true,
              showDate: true,
              onOpen: () => openMealCompletion(context, mealId: meal.id),
              onDelete: deleteAction(meal),
            ),
          if (groups.isNotEmpty)
            MealProgressSectionHeading(title: lang.dashboardPlannedMealsTitle),
          for (final group in groups) ...[
            MealProgressSectionHeading(
              title: mealScheduleDateLabel(context, group.date, now),
              date:
                  group.date == null ||
                      mealScheduleDateLabel(context, group.date, now) ==
                          mealScheduleFullDate(context, group.date!)
                  ? null
                  : mealScheduleFullDate(context, group.date!),
            ),
            for (final meal in group.meals)
              MealScheduleTile(
                meal: meal,
                enabled: blockingMeal == null || blockingMeal.id == meal.id,
                onOpen: () => openExistingActions(meal),
                onDelete: deleteAction(meal),
              ),
          ],
        ],
      ),
    );
  }
}

domain.Meal? firstMealBlockingActivation(Iterable<domain.Meal> meals) {
  for (final meal in meals) {
    if (mealStatusBlocksAnotherMealActivation(meal.status)) return meal;
  }
  return null;
}
