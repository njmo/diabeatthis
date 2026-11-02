import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../meal/meal_progress_plan.dart';
import 'meal_progress_step.dart';

class MealProgressSteps extends StatelessWidget {
  const MealProgressSteps({super.key, required this.plan});

  final MealProgressPlan plan;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < plan.stages.length; index++) ...[
        if (index > 0) const SizedBox(width: 10),
        Expanded(
          child: MealProgressStep(
            label: switch (plan.stages[index]) {
              MealProgressStage.bolus => lang.mealProgressBolus,
              MealProgressStage.waiting => lang.mealProgressWaiting,
              MealProgressStage.eating => lang.mealProgressEating,
              MealProgressStage.extra => lang.mealSummaryExtraTitle,
            },
            complete: plan.isComplete(index),
            current: index == plan.currentIndex,
          ),
        ),
      ],
    ],
  );
}
