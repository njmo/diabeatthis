import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../../../features/meal_advisor/domain/models/wait_suggestion.dart';
import '../../../l10n/language.dart';
import '../../../widgets/meal_start/meal_start_plan.dart';
import '../../demo/meal_decision_demo_request.dart';

class MealDecisionDemoResponseView extends StatelessWidget {
  const MealDecisionDemoResponseView({super.key, required this.request});
  final MealDecisionDemoRequest request;
  @override
  Widget build(BuildContext context) {
    final answer = request.answer;
    if (answer == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(context.lang.mealDecisionCaregiver),
          subtitle: Text(
            request.caregiverName ?? context.lang.mealDecisionDemoCaregiver,
          ),
        ),
        const SizedBox(height: 12),
        if (request.deferredUntil != null) ...[
          Text(
            context.lang.mealDecisionDeferredUntil(
              DateFormat.Hm(
                context.lang.localeName,
              ).format(request.deferredUntil!),
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(context.lang.mealDecisionDuration(request.waitMinutes)),
          if (request.suggestMealTarget)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(context.lang.mealDecisionMealTargetSuggested),
              subtitle: Text(context.lang.mealDecisionTargetDemoOnly),
            ),
        ] else
          MealStartPlan(
            advice: MealAdvice(
              answer.decision,
              answer.requiresMinutes
                  ? WaitSuggestion(
                      request.waitMinutes,
                      request.waitMinutes,
                      request.waitMinutes,
                    )
                  : null,
              source: 'caregiverDemo',
            ),
          ),
        if (request.message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(request.message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ],
    );
  }
}
