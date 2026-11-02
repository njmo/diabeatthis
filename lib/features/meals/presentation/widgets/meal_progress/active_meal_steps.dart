import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/meal/meal_progress_plan.dart';
import '../../../../../common/widgets/meal_progress/meal_progress_steps.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../data/providers/meal_progress_plan_provider.dart';

class ActiveMealSteps extends ConsumerWidget {
  const ActiveMealSteps({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsHistory =
        meal.status == 'waiting-for-bolus' ||
        meal.status == 'eating-extra' ||
        meal.status == 'eating';
    final plan = needsHistory
        ? ref.watch(mealProgressPlanProvider(meal)).asData?.value
        : null;
    return MealProgressSteps(
      plan: plan ?? mealProgressPlanForStatus(meal.status),
    );
  }
}
