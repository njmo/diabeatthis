import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/meal/calculator/meal_calculator_entries_provider.dart';
import '../../../../common/meal/meal_bolus_shortfall.dart';
import '../../../../common/meal/meal_display_name.dart';
import '../../../../common/meal/meal_progress_plan.dart';
import '../../../../common/meal/meal_treatment_surplus.dart';
import '../../../../common/meal/open_meal_add_on.dart';
import '../../../../common/meal/open_meal_completion.dart';
import '../../../../common/meal_advisor/presentation/remote/child_meal_decision_meal_action.dart';
import '../../../../common/monitoring/meal_wait_status.dart';
import '../../../../common/notifications/scoped_notification_cancellation.dart';
import '../../../../common/widgets/meal_progress/active_meal_progress_card.dart';
import '../../../../common/widgets/meal_progress/meal_progress_section_heading.dart';
import '../../../../common/widgets/meal_progress/meal_progress_steps.dart';
import '../../../../common/widgets/meal_progress/show_meal_interruption_dialog.dart';
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/notifications/domain/models/notification_event_type.dart';
import '../../../../core/notifications/domain/models/notification_key.dart';
import '../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../foreground/event/internal/meal_bolus_continued_manually.dart';
import '../../../dashboard/data/providers/time_now_provider.dart';
import '../../../dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../../dashboard/presentation/utils/show_meal_status_dialog.dart';
import '../../data/domain/use_cases/continue_meal_without_bolus_link.dart';
import '../../data/providers/meal_activation_guard_provider.dart';
import '../../data/providers/meal_add_on_bolus_context_provider.dart';
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
    ].where((meal) => mealStatusAppearsOnDashboard(meal.status)).toList();
    final activeMeals = visibleMeals
        .where((meal) => mealStatusBlocksAnotherMealActivation(meal.status))
        .toList();
    final treatmentSurpluses = activeMeals.isEmpty
        ? null
        : ref.watch(mealTreatmentSurplusesProvider).value;
    final calculatorEntries =
        activeMeals.any((meal) => meal.status == 'waiting-for-bolus')
        ? ref.watch(mealCalculatorEntriesProvider).value
        : null;
    bool calculatorEntryRecorded(domain.Meal meal) =>
        meal.status == 'waiting-for-bolus' &&
        calculatorEntries?.contains(meal.id) == true;
    final insulinFormat = NumberFormat.decimalPattern(lang.localeName)
      ..maximumFractionDigits = 3;
    final bolusWarnings = {
      for (final meal in activeMeals)
        meal.id: [
          for (final dose
              in ref.watch(mealBolusShortfallsProvider(meal.id)).value ??
                  const <MealBolusShortfall>[])
            lang.mealBolusBelowCalculator(
              insulinFormat.format(dose.delivered),
              insulinFormat.format(dose.recommended),
            ),
        ],
    };
    final addOnProgress = {
      for (final meal in activeMeals)
        meal.id: ref
            .watch(mealAddOnBolusContextProvider(meal.id))
            .asData
            ?.value,
    };
    final progressPlans = {
      for (final meal in activeMeals)
        meal.id: watchActiveMealPlan(
          ref,
          meal,
          fallbackAddOn: addOnProgress[meal.id],
        ),
    };
    bool waitingForExtraBolus(domain.Meal meal) =>
        meal.status == 'eating-extra' &&
        progressPlans[meal.id]?.currentStage == MealProgressStage.bolus;
    final waitState =
        activeMeals.any((meal) => meal.status == 'bolused-waiting')
        ? ref.watch(mealWaitStatusProvider).value
        : null;
    bool waitsForExtendedCarbs(domain.Meal meal) =>
        meal.status == 'bolused-waiting' &&
        waitState?.mealId == meal.id &&
        waitState?.waitingForExtendedCarbs == true;
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

    Future<void> confirmManualContinuation(int mealId) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 360),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          titleTextStyle: Theme.of(dialog).textTheme.titleMedium,
          title: Text(lang.mealProgressContinueWithoutBolusLinkTitle),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          contentTextStyle: Theme.of(dialog).textTheme.bodyMedium,
          content: Text(lang.mealProgressContinueWithoutBolusLinkBody),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(lang.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(lang.mealProgressContinueWithoutBolusLinkConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      try {
        final notifications = ref.read(notificationsControllerUiProvider);
        final router = ref.read(appEventRouterProvider);
        if (await continueMealWithoutBolusLink(
          ref.read(databaseProvider),
          mealId,
        )) {
          router.send(MealBolusContinuedManually(mealId));
          await notifications.cancelNotification(
            NotificationKey(
              type: NotificationEventType.mealSuggestion,
              entityId: mealId,
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(lang.familyPlanFailed)));
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
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
              status: mealStatusLabel(
                waitingForExtraBolus(meal)
                    ? 'waiting-for-bolus'
                    : meal.status ?? 'planned',
              ),
              schedule: mealScheduleLabel(context, meal.plannedAt, now),
              steps: MealProgressSteps(plan: progressPlans[meal.id]!),
              treatmentSurplus: treatmentSurpluses?.contains(meal.id) == true,
              bolusWarnings: bolusWarnings[meal.id]!,
              waitingForBolus:
                  !calculatorEntryRecorded(meal) &&
                  progressPlans[meal.id]?.currentStage ==
                      MealProgressStage.bolus,
              progressAction: meal.status == 'eating-extra'
                  ? ActiveMealAddOnBolusAction(mealId: meal.id)
                  : null,
              actionLabel: meal.status == 'bolused-waiting'
                  ? lang.mealStatusStartEating
                  : meal.status == 'waiting-for-bolus'
                  ? calculatorEntryRecorded(meal)
                        ? lang.mealProgressContinueWithoutBolusLinkTitle
                        : lang.mealProgressOpenCalculator
                  : lang.mealStatusAte,
              onActionLongPress:
                  meal.status == 'waiting-for-bolus' &&
                      !waitingForExtraBolus(meal) &&
                      !waitsForExtendedCarbs(meal)
                  ? () => confirmManualContinuation(meal.id)
                  : null,
              onAction:
                  waitingForExtraBolus(meal) || waitsForExtendedCarbs(meal)
                  ? null
                  : () async {
                      if (mealStatusesStartingEating.contains(meal.status) ||
                          meal.status == 'eating-extra') {
                        openMealCompletion(context, mealId: meal.id);
                      } else if (meal.status == 'waiting-for-bolus') {
                        if (calculatorEntryRecorded(meal)) {
                          await confirmManualContinuation(meal.id);
                          return;
                        }
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
              onAddFood:
                  mealStatusesStartingEating.contains(meal.status) &&
                      addOnProgress[meal.id]?.additionalServing != true
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
              date: groupFullDate(context, group.date, now),
            ),
            for (final meal in group.meals)
              MealScheduleTile(
                meal: meal,
                enabled: blockingMeal == null || blockingMeal.id == meal.id,
                onOpen: () => openExistingActions(meal),
                cardDetails: ChildMealDecisionMealAction(mealId: meal.id),
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

/// The full date next to a relative label, omitted when it would repeat it.
String? groupFullDate(BuildContext context, DateTime? date, DateTime now) {
  if (date == null) return null;
  final full = mealScheduleFullDate(context, date);
  return mealScheduleDateLabel(context, date, now) == full ? null : full;
}
