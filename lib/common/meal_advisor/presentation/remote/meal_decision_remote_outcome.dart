import 'package:flutter/material.dart';

import '../../../l10n/language.dart';
import '../../../meal/manual_meal_decision.dart';
import '../../meal_decision_answer.dart';
import '../../remote/meal_decision_remote_request.dart';

class MealDecisionRemoteOutcome extends StatelessWidget {
  const MealDecisionRemoteOutcome({super.key, required this.request});
  final MealDecisionRemoteRequest request;
  @override
  Widget build(BuildContext context) {
    final outcome = request.data['outcome'] as Map?;
    final answer = MealDecisionAnswer.values
        .where((a) => a.name == outcome?['decision'])
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.lang.mealDecisionRemoteExpired),
        if (answer?.decision != null) ...[
          const SizedBox(height: 8),
          Text(
            outcome?['source'] == 'manual'
                ? context.lang.uiManualDecision
                : context.lang.mealStartAdvisorProposal,
          ),
          Text(
            mealDecisionLabel(answer!.decision!),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (answer.requiresMinutes && outcome?['minutes'] is int)
            Text(context.lang.mealDecisionDuration(outcome!['minutes'] as int)),
        ],
      ],
    );
  }
}
