import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/logger/logger.dart';
import '../../../meal_summary/domain/utils/meal_add_on_status.dart';
import '../../data/meal_dialog_controller.dart';
import '../../data/meal_dialog_state.dart';
import '../../data/providers/meal_advisor_result_provider.dart';
import '../../data/providers/meal_snapshot_controller_provider.dart';
import '../../data/utils/meal_advisor.dart';
import 'meal_add_on_mode_dialog.dart';
import 'meal_status_dialog_result.dart';

class MealStatusDialog extends ConsumerWidget with Logging {
  final Meal meal;
  const MealStatusDialog({required this.meal, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(mealDialogControllerProvider(meal.id, getStep()));
    final c = ref.read(
      mealDialogControllerProvider(meal.id, getStep()).notifier,
    );

    Widget content() {
      switch (s.step) {
        case MealDialogStep.choose:
          return Padding(
            padding: EdgeInsetsGeometry.directional(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsetsGeometry.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        child: InkWell(
                          onTap: c.chooseEat,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant_outlined, size: 60),
                              Text(context.lang.mealStatusEatChoice),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Container(
                        padding: EdgeInsetsGeometry.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        child: InkWell(
                          onTap: c.chooseSkip,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.no_meals, size: 60),
                              Text(context.lang.mealStatusSkipChoice),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (s.activationBlockedByMealName != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.lang.mealStatusActivationBlocked(
                      s.activationBlockedByMealName!,
                    ),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          );
        case MealDialogStep.confirm:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.skipMeal) Text(context.lang.mealStatusConfirmSkipTitle),
              if (s.skipMeal)
                Text(context.lang.mealStatusConfirmSkipMessage)
              else if (s.advice.decision != null)
                Text(
                  context.lang.mealStatusAdviceToApply(
                    c.mealAdviceString() ?? '',
                  ),
                ),
            ],
          );
        case MealDialogStep.confirmEaten:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text(context.lang.mealStatusConfirmEaten)],
          );
        case MealDialogStep.confirmEating:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text(context.lang.mealStatusConfirmEating)],
          );
        case MealDialogStep.confirmBolusedAfterEating:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text(context.lang.mealStatusBolusAfterEating)],
          );
        case MealDialogStep.waitingForBolus:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text(context.lang.mealStatusWaitingForBolus)],
          );
      }
    }

    List<Widget> actions() {
      switch (s.step) {
        case MealDialogStep.choose:
          return [const SizedBox.shrink()];
        case MealDialogStep.confirm:
          return [
            TextButton(
              onPressed: () async {
                if (!s.skipMeal) {
                  await c.cancelAllMealNotifications();
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(context.lang.settingsCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  if (!s.skipMeal) {
                    await c.cancelAllMealNotifications();

                    await ref.read(insertAdviceProvider(meal, s.advice).future);

                    try {
                      final mealSummaryController = ref.read(
                        mealSnapshotControllerProvider,
                      );
                      await mealSummaryController.createPlannedSnapshot(
                        meal.id,
                      );
                    } catch (e) {
                      logE("Error creating snapshot for meal: $e");
                    }
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop(
                      MealStatusUpdateResult(
                        s.skipMeal
                            ? 'skipped'
                            : s.advice.decision!.acceptedStatus,
                      ),
                    );
                  }
                }
              },
              child: Text(_buttonText(s.advice.decision)),
            ),
          ];
        case MealDialogStep.confirmEaten:
          return [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.lang.settingsCancel),
            ),
            if (mealStatusCanRequestAddOn(meal.status))
              OutlinedButton.icon(
                onPressed: () => _chooseAddOn(context),
                icon: const Icon(Icons.add),
                label: Text(context.lang.mealSummaryExtraTitle),
              ),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  Navigator.of(context).pop(
                    MealStatusUpdateResult(
                      mealStatusAfterEatingConfirmation(meal.status),
                    ),
                  );
                }
              },
              child: Text(context.lang.mealStatusAte),
            ),
          ];

        case MealDialogStep.confirmEating:
          return [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.lang.settingsCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  final status = meal.status == 'bolused-waiting'
                      ? 'waited-eating'
                      : 'eating';
                  Navigator.of(context).pop(MealStatusUpdateResult(status));
                }
              },
              child: Text(context.lang.mealStatusEatingAction),
            ),
          ];
        case MealDialogStep.confirmBolusedAfterEating:
          return [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.lang.settingsCancel),
            ),
            if (mealStatusCanRequestAddOn(meal.status))
              OutlinedButton.icon(
                onPressed: () => _chooseAddOn(context),
                icon: const Icon(Icons.add),
                label: Text(context.lang.mealSummaryExtraTitle),
              ),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pop(const MealStatusUpdateResult('waiting-for-bolus'));
                }
              },
              child: Text(context.lang.mealStatusDeliverBolus),
            ),
          ];
        case MealDialogStep.waitingForBolus:
          return [
            TextButton(
              onPressed: () async {
                await c.cancelAllMealNotifications();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pop(const MealStatusUpdateResult('skipped'));
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.lang.mealStatusCancelMeal),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.lang.notificationActionOk),
            ),
          ];
      }
    }

    return AlertDialog(
      title: Text(meal.name),
      content: content(),
      actions: actions(),
    );
  }

  String _buttonText(MealDecision? decision) {
    switch (decision) {
      case MealDecision.eatNowBolusLater:
        return lang.mealStatusStartEating;
      case MealDecision.bolusAndEatNow:
        return lang.mealStatusDeliverBolus;
      case MealDecision.bolusWaitThenEat:
        return lang.mealStatusDeliverBolusAndWait;
      case MealDecision.bolus:
      case null:
        return lang.mealStatusConfirm;
    }
  }

  MealDialogStep getStep() {
    switch (meal.status) {
      case 'bolused-waiting':
        return MealDialogStep.confirmEating;
      case 'waiting-for-bolus':
        return MealDialogStep.waitingForBolus;
      case 'eating-then-bolus':
        return MealDialogStep.confirmBolusedAfterEating;
      case 'waited-eating':
      case 'bolused-eating':
      case 'eating':
      case 'eating-extra':
        return MealDialogStep.confirmEaten;
      default:
        return MealDialogStep.choose;
    }
  }

  Future<void> _chooseAddOn(BuildContext context) async {
    final choice = await showDialog<MealAddOnChoice?>(
      context: context,
      builder: (context) => const MealAddOnModeDialog(),
    );

    if (choice == null || !context.mounted) {
      return;
    }

    Navigator.of(context).pop(MealStatusAddOnResult(choice));
  }
}
