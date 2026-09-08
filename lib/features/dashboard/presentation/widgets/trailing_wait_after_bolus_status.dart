import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/model/meal.dart';
import '../../../../core/logger/logger.dart';
import '../../../meals/data/providers/meal_status_history_provider.dart';
import '../../data/providers/meal_advisor_result_provider.dart';
import '../../data/providers/time_now_provider.dart';

class TrailingWaitAfterBolusStatus extends HookConsumerWidget with Logging {
  final Meal meal;
  const TrailingWaitAfterBolusStatus({super.key, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeNow = ref.watch(timeNowProvider);
    final mealAdvice = ref.watch(getMealAdviceProvider(meal));
    final waitStartedAt = ref.watch(
      mealStatusStartedAtProvider(
        MealStatusStartedAtRequest(mealId: meal.id, status: 'bolused-waiting'),
      ),
    );

    if (mealAdvice.isLoading || timeNow.isLoading || waitStartedAt.isLoading) {
      return const SizedBox.shrink();
    }

    final advice = mealAdvice.asData?.value;
    final timeNowDate = timeNow.asData?.value;
    final waitStartedAtDate = waitStartedAt.asData?.value;
    final recommendedMinutes = advice?.wait?.recommendedMinutes;

    if (advice == null ||
        timeNowDate == null ||
        waitStartedAtDate == null ||
        recommendedMinutes == null) {
      return const SizedBox.shrink();
    }

    final elapsedWaitMinutes = timeNowDate
        .difference(waitStartedAtDate)
        .inMinutes;

    logI('elapsedWaitMinutes: $elapsedWaitMinutes');
    logI('recommendedMinutes: $recommendedMinutes');

    final minutesLeft = recommendedMinutes - elapsedWaitMinutes;
    return SizedBox(
      width: 52,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '${minutesLeft}min',
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            color: minutesLeft > 0
                ? Theme.of(context).colorScheme.onSurface
                : Colors.red,
          ),
        ),
      ),
    );
  }
}
