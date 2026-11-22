import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/meal/meal_add_on_bolus_context.dart';
import '../../../../../common/meal/meal_progress_plan.dart';
import '../../../../../common/widgets/meal_progress/meal_progress_steps.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../data/providers/meal_progress_plan_provider.dart';

class ActiveMealSteps extends ConsumerWidget {
  const ActiveMealSteps({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MealProgressSteps(plan: watchActiveMealPlan(ref, meal));
  }
}

MealProgressPlan watchActiveMealPlan(
  WidgetRef ref,
  Meal meal, {
  MealAddOnBolusContext? fallbackAddOn,
}) {
  final needsHistory = const {
    'waiting-for-bolus',
    'eating-extra',
    'eating',
  }.contains(meal.status);
  final plan = needsHistory
      ? ref.watch(mealProgressPlanProvider(meal)).asData?.value
      : null;
  return plan ?? mealProgressPlanForStatus(meal.status, addOn: fallbackAddOn);
}
