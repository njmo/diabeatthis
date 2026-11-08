import 'package:flutter/material.dart';

import '../../../l10n/language.dart';
import '../../../meal/manual_meal_decision.dart';
import '../../../widgets/manual_meal_decision_option.dart';
import '../../demo/meal_decision_demo_answer.dart';

class MealDecisionDemoOptions extends StatelessWidget {
  const MealDecisionDemoOptions({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final MealDecisionDemoAnswer value;
  final ValueChanged<MealDecisionDemoAnswer> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final answer in MealDecisionDemoAnswer.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ManualMealDecisionOption(
            label: answer == MealDecisionDemoAnswer.deferMeal
                ? context.lang.mealDecisionDefer
                : mealDecisionLabel(answer.decision!),
            icon: switch (answer) {
              MealDecisionDemoAnswer.insulinThenWait => Icons.schedule_outlined,
              MealDecisionDemoAnswer.insulinAndEat => Icons.restaurant_outlined,
              MealDecisionDemoAnswer.eatThenInsulin => Icons.redo,
              MealDecisionDemoAnswer.deferMeal =>
                Icons.event_available_outlined,
            },
            selected: value == answer,
            onPressed: () => onChanged(answer),
          ),
        ),
    ],
  );
}
