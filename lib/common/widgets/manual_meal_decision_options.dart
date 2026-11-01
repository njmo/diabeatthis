import 'package:flutter/material.dart';

import '../meal/manual_meal_decision.dart';
import '../meal/meal_decision.dart';
import 'manual_meal_decision_option.dart';

class ManualMealDecisionOptions extends StatelessWidget {
  const ManualMealDecisionOptions({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MealDecision value;
  final ValueChanged<MealDecision> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final decision in [
        MealDecision.bolusWaitThenEat,
        MealDecision.bolusAndEatNow,
        MealDecision.eatNowBolusLater,
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ManualMealDecisionOption(
            label: mealDecisionLabel(decision),
            icon: switch (decision) {
              MealDecision.bolusWaitThenEat => Icons.schedule_outlined,
              MealDecision.bolusAndEatNow => Icons.restaurant_outlined,
              _ => Icons.redo,
            },
            selected: value == decision,
            onPressed: () => onChanged(decision),
          ),
        ),
    ],
  );
}
