import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../meal/manual_meal_decision.dart';
import '../../widgets/manual_meal_decision_option.dart';
import '../meal_decision_answer.dart';

class MealDecisionOptions extends StatelessWidget {
  const MealDecisionOptions({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final MealDecisionAnswer value;
  final ValueChanged<MealDecisionAnswer> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final answer in MealDecisionAnswer.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ManualMealDecisionOption(
            label: answer == MealDecisionAnswer.deferMeal
                ? context.lang.mealDecisionDefer
                : mealDecisionLabel(answer.decision!),
            icon: switch (answer) {
              MealDecisionAnswer.insulinThenWait => Icons.schedule_outlined,
              MealDecisionAnswer.insulinAndEat => Icons.restaurant_outlined,
              MealDecisionAnswer.eatThenInsulin => Icons.redo,
              MealDecisionAnswer.deferMeal => Icons.event_available_outlined,
            },
            selected: value == answer,
            onPressed: () => onChanged(answer),
          ),
        ),
    ],
  );
}
