import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/manual_meal_decision.dart';
import '../../../../common/widgets/ai_text_dialog.dart';
import '../../../../common/widgets/manual_meal_decision_dialog.dart';
import '../../../../common/widgets/meal_start/meal_advice_unavailable.dart';
import '../../../../common/widgets/meal_start/meal_start_actions.dart';
import '../../../../common/widgets/meal_start/meal_start_choice.dart';
import '../../../../common/widgets/meal_start/meal_start_sheet.dart';
import '../../../../common/widgets/meal_start/meal_start_summary.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/logger/logger.dart';
import '../../../meal_summary/domain/utils/meal_add_on_status.dart';
import '../../data/meal_dialog_controller.dart';
import '../../data/meal_dialog_state.dart';
import '../../data/utils/meal_advisor.dart';
import '../utils/meal_status_dialog_result_handler.dart';
import 'meal_add_on_mode_dialog.dart';
import 'meal_advice_loading.dart';
import 'meal_status_dialog_result.dart';

class MealStatusDialog extends HookConsumerWidget with Logging {
  final Meal meal;
  const MealStatusDialog({required this.meal, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saving = useState(false);
    final s = ref.watch(mealDialogControllerProvider(meal.id, getStep()));
    final c = ref.read(
      mealDialogControllerProvider(meal.id, getStep()).notifier,
    );

    Future<void> chooseManual() async {
      if (s.isPreparingAdvice) c.cancelAdvicePreparation();
      final manual = await showDialog<ManualMealDecision>(
        context: context,
        builder: (_) => ManualMealDecisionDialog(
          showAllDecisions: true,
          preservesMealValues: s.advice.decision != null,
          initialValue: ManualMealDecision(
            decision: s.advice.decision ?? MealDecision.bolusAndEatNow,
            waitMinutes: s.advice.wait?.recommendedMinutes ?? 0,
          ),
        ),
      );
      if (manual != null && context.mounted) await c.chooseEat(manual: manual);
    }

    Widget content() {
      if (s.isPreparingAdvice) {
        return MealAdviceLoading(
          aiAssisted: s.isAiAssisted,
          onManual: chooseManual,
        );
      }
      switch (s.step) {
        case MealDialogStep.choose:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.lang.mealStartChoicePrompt,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              MealStartChoice(onEat: c.chooseEat, onSkip: c.chooseSkip),
              if (s.activationBlockedByMealName != null) ...[
                const SizedBox(height: 12),
                Text(
                  context.lang.mealStatusActivationBlocked(
                    s.activationBlockedByMealName!,
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          );
        case MealDialogStep.confirm:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.isAiAssisted && s.advisorInput != null)
                TextButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: Text(context.lang.dayAiShowInput),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AiTextDialog(text: s.advisorInput!.text),
                  ),
                ),
              if (s.preparationFailed)
                Text(context.lang.mealAdvicePreparationFailed),
              if (s.skipMeal) Text(context.lang.mealStatusConfirmSkipTitle),
              if (s.skipMeal)
                Text(context.lang.mealStatusConfirmSkipMessage)
              else if (s.advice.decision != null)
                MealStartSummary(
                  advice: s.advice,
                  carbsGrams: s.carbsGrams,
                  extendedCarbsGrams: s.extendedCarbsGrams,
                )
              else if (!s.preparationFailed)
                MealAdviceUnavailable(
                  reason: s.unavailableReason,
                  onRetry: saving.value ? null : c.chooseEat,
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
              onPressed: saving.value
                  ? null
                  : () async {
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
              onPressed:
                  saving.value ||
                      s.isPreparingAdvice ||
                      (!s.skipMeal && s.advice.decision == null)
                  ? null
                  : () async {
                      saving.value = true;
                      if (context.mounted) {
                        if (!s.skipMeal) {
                          await c.cancelAllMealNotifications();

                          try {
                            final accepted = await c.confirmAdvice();
                            if (!accepted) {
                              if (context.mounted) saving.value = false;
                              return;
                            }
                          } catch (e) {
                            if (context.mounted) {
                              saving.value = false;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.lang.mealDecisionSaveError(
                                      e.toString(),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop(
                            MealStatusUpdateResult(
                              s.skipMeal
                                  ? 'skipped'
                                  : s.advice.decision!.acceptedStatus,
                              alreadySaved: !s.skipMeal,
                            ),
                          );
                        }
                      }
                    },
              style: getStep() == MealDialogStep.choose
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    )
                  : null,
              child: Text(
                s.skipMeal
                    ? context.lang.mealStatusConfirm
                    : _buttonText(s.advice.decision),
              ),
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

    if (getStep() == MealDialogStep.choose) {
      final confirming =
          s.step == MealDialogStep.confirm && !s.isPreparingAdvice;
      final canEdit = confirming && !s.skipMeal;
      final opensAaps =
          canEdit &&
          s.advice.decision != null &&
          shouldCreateAapsSuggestionForMealStatus(
            s.advice.decision!.acceptedStatus,
            extendedCarbsGrams: s.extendedCarbsGrams.ceil(),
          );
      Future<void> close() async {
        saving.value = true;
        if (confirming && !s.skipMeal) await c.cancelAllMealNotifications();
        if (context.mounted) Navigator.of(context).pop();
      }

      Future<void> backToChoice() async {
        saving.value = true;
        if (!s.skipMeal) await c.cancelPendingAdviceReminder();
        if (!context.mounted) return;
        c.back();
        saving.value = false;
      }

      return PopScope(
        canPop: !saving.value,
        child: MealStartSheet(
          title: s.step == MealDialogStep.choose
              ? context.lang.mealStartChoiceTitle
              : meal.name,
          subtitle: s.step == MealDialogStep.choose || s.skipMeal
              ? meal.name
              : s.advice.source == 'manual'
              ? context.lang.uiManualDecision
              : context.lang.mealStartAdvisorProposal,
          onBack: confirming && !saving.value ? backToChoice : null,
          onClose: saving.value ? null : close,
          body: AbsorbPointer(absorbing: saving.value, child: content()),
          actions: confirming
              ? MealStartActions(
                  confirmAction: actions().last,
                  cancelAction: actions().first,
                  showDecisionChange: canEdit,
                  hasAdvice: s.advice.decision != null,
                  opensAaps: opensAaps,
                  onChangeDecision: saving.value ? null : chooseManual,
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    return PopScope(
      canPop: !saving.value,
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(meal.name)),
            if (s.step == MealDialogStep.confirm && !s.skipMeal)
              IconButton(
                tooltip: context.lang.uiChooseADecisionManually,
                icon: const Icon(Icons.edit_outlined),
                onPressed: saving.value ? null : chooseManual,
              ),
          ],
        ),
        content: content(),
        actions: actions(),
      ),
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
