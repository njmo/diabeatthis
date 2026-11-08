import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../../../features/meal_advisor/domain/models/wait_suggestion.dart';
import '../../../l10n/language.dart';
import '../../../meal/manual_meal_decision.dart';
import '../../../meal/meal_decision.dart';
import '../../../widgets/manual_meal_decision_dialog.dart';
import '../../../widgets/meal_start/meal_start_plan.dart';
import '../../demo/meal_decision_demo_controller.dart';
import '../../demo/meal_decision_demo_request.dart';
import '../../meal_decision_preferences.dart';

/// Exercises only the fallback UI contract, with no real algorithm or meal writes.
class MealDecisionDemoFallbackAction extends ConsumerWidget {
  const MealDecisionDemoFallbackAction({super.key, required this.request});
  final MealDecisionDemoRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
    child: Text(
      request.timeoutFallback == MealDecisionTimeoutFallback.manual
          ? context.lang.uiChooseManually
          : context.lang.mealDecisionTimeoutOpenApp,
    ),
    onPressed: () async {
      MealAdvice? advice;
      if (request.timeoutFallback == MealDecisionTimeoutFallback.manual) {
        final selected = await showDialog<ManualMealDecision>(
          context: context,
          builder: (_) => const ManualMealDecisionDialog(),
        );
        if (selected == null || !context.mounted) return;
        advice = MealAdvice(
          selected.decision,
          selected.waitMinutes > 0
              ? WaitSuggestion(
                  selected.waitMinutes,
                  selected.waitMinutes,
                  selected.waitMinutes,
                )
              : null,
          source: 'manualDemo',
        );
      } else {
        final sample = MealAdvice(
          MealDecision.bolusAndEatNow,
          null,
          source: 'mealAdvisorDemo',
        );
        final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.lang.mealDecisionTimeoutAppDemo),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.lang.mealDecisionTimeoutAppDisclosure),
                const SizedBox(height: 12),
                MealStartPlan(advice: sample),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.lang.settingsCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.lang.mealDecisionDemoAccept),
              ),
            ],
          ),
        );
        if (accepted != true || !context.mounted) return;
        advice = sample;
      }
      ref
          .read(mealDecisionDemoControllerProvider.notifier)
          .completeFallback(request.key, request.id, advice);
    },
  );
}
