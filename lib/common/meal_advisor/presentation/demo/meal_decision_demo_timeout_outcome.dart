import 'package:flutter/material.dart';

import '../../../l10n/language.dart';
import '../../../meal/manual_meal_decision.dart';
import '../../demo/meal_decision_demo_request.dart';
import '../../meal_decision_preferences.dart';

class MealDecisionDemoTimeoutOutcome extends StatelessWidget {
  const MealDecisionDemoTimeoutOutcome({super.key, required this.request});
  final MealDecisionDemoRequest request;

  @override
  Widget build(BuildContext context) {
    final advice = request.fallbackAdvice;
    if (advice == null) return Text(context.lang.mealDecisionTimeoutWaiting);
    return Text(
      context.lang.mealDecisionTimeoutOutcome(
        request.timeoutFallback == MealDecisionTimeoutFallback.app
            ? context.lang.mealDecisionTimeoutAppDemo
            : context.lang.mealDecisionTimeoutManualDemo,
        '${mealDecisionLabel(advice.decision!)}${advice.wait == null ? '' : ' · ${context.lang.mealDecisionDuration(advice.wait!.recommendedMinutes)}'}',
      ),
    );
  }
}
