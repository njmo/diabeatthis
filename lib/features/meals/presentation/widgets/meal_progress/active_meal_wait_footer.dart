import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/widgets/meal_progress/meal_wait_progress.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../dashboard/data/providers/meal_advisor_result_provider.dart';
import '../../../../dashboard/data/providers/time_now_provider.dart';
import '../../../data/providers/meal_status_history_provider.dart';

class ActiveMealWaitFooter extends ConsumerWidget {
  const ActiveMealWaitFooter({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(timeNowProvider).asData?.value;
    final advice = ref.watch(getMealAdviceProvider(meal)).asData?.value;
    final startedAt = ref
        .watch(
          mealStatusStartedAtProvider(
            MealStatusStartedAtRequest(
              mealId: meal.id,
              status: 'bolused-waiting',
            ),
          ),
        )
        .asData
        ?.value;
    final minutes = advice?.wait?.recommendedMinutes;
    if (now == null || startedAt == null || minutes == null) {
      return const SizedBox.shrink();
    }
    final total = Duration(minutes: minutes);
    return MealWaitProgress(
      remaining: total - now.difference(startedAt),
      total: total,
    );
  }
}
