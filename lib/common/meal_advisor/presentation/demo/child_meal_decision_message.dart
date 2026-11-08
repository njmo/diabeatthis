import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/language.dart';
import '../../../meal/manual_meal_decision.dart';
import '../../demo/meal_decision_demo_answer.dart';
import '../../demo/meal_decision_demo_request.dart';

/// The child's response is a short message, not a clinical dashboard.
class ChildMealDecisionMessage extends StatelessWidget {
  const ChildMealDecisionMessage({super.key, required this.request});
  final MealDecisionDemoRequest request;

  @override
  Widget build(BuildContext context) {
    final answer = request.answer;
    if (answer == null) return const SizedBox.shrink();
    final decision = answer == MealDecisionDemoAnswer.deferMeal
        ? context.lang.mealDecisionDeferredUntil(
            DateFormat.Hm(
              context.lang.localeName,
            ).format(request.deferredUntil!),
          )
        : mealDecisionLabel(answer.decision!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.mealDecisionDemoFromCaregiver(
            request.caregiverName ?? context.lang.mealDecisionCaregiver,
          ),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Text(decision, style: Theme.of(context).textTheme.titleLarge),
        if (answer.requiresMinutes) ...[
          const SizedBox(height: 4),
          Text(context.lang.mealDecisionDuration(request.waitMinutes)),
        ],
        if (request.message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(request.message, style: Theme.of(context).textTheme.bodyLarge),
        ],
        if (request.suggestMealTarget) ...[
          const SizedBox(height: 8),
          Text(context.lang.mealDecisionMealTargetSuggested),
        ],
      ],
    );
  }
}
