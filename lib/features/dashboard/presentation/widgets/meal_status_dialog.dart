import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                          color: Colors.white70,
                        ),
                        child: InkWell(
                          onTap: c.chooseEat,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant_outlined, size: 60),
                              Text('Zjem'),
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
                          color: Colors.white70,
                        ),
                        child: InkWell(
                          onTap: c.chooseSkip,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.no_meals, size: 60),
                              Text('Pomijam'),
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
                    'Najpierw zakończ aktywny posiłek: ${s.activationBlockedByMealName}.',
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
              if (s.skipMeal) const Text("Potwierdź pominięcie posiłku"),
              if (s.skipMeal)
                const Text("Zapiszemy, że posiłek został pominięty.")
              else if (s.advice.decision != null)
                Text("Propozycja do wykonania: \n\n${c.mealAdviceString()}\n"),
            ],
          );
        case MealDialogStep.confirmEaten:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('Potwierdź że posiłek został zjedzony')],
          );
        case MealDialogStep.confirmEating:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('Potwierdź że zacząłeś jeść')],
          );
        case MealDialogStep.confirmBolusedAfterEating:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('Podaj bolusa po zjedzeniu.')],
          );
        case MealDialogStep.waitingForBolus:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('Czekamy na bolus z kalkulatora.')],
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
              child: const Text("Anuluj"),
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
              child: const Text("Anuluj"),
            ),
            if (mealStatusCanRequestAddOn(meal.status))
              OutlinedButton.icon(
                onPressed: () => _chooseAddOn(context),
                icon: const Icon(Icons.add),
                label: const Text('Dokładka'),
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
              child: const Text("Zjadłem"),
            ),
          ];

        case MealDialogStep.confirmEating:
          return [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anuluj"),
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
              child: const Text("Jem"),
            ),
          ];
        case MealDialogStep.confirmBolusedAfterEating:
          return [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anuluj"),
            ),
            if (mealStatusCanRequestAddOn(meal.status))
              OutlinedButton.icon(
                onPressed: () => _chooseAddOn(context),
                icon: const Icon(Icons.add),
                label: const Text('Dokładka'),
              ),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pop(const MealStatusUpdateResult('waiting-for-bolus'));
                }
              },
              child: const Text("Podaję bolusa"),
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
              child: const Text("Anuluj posiłek"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
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
        return "Zaczynam jeść";
      case MealDecision.bolusAndEatNow:
        return "Podaje bolusa";
      case MealDecision.bolusWaitThenEat:
        return "Podaje bolusa i czekam";
      case MealDecision.bolus:
      case null:
        return 'Potwierdzam';
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
