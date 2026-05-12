import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/model/meal.dart';
import '../../../../core/logger/logger.dart';
import '../../data/providers/meal_advisor_result_provider.dart';
import '../../data/providers/time_now_provider.dart';

class TrailingWaitAfterBolusStatus extends HookConsumerWidget with Logging {
  final Meal meal;
  const TrailingWaitAfterBolusStatus({super.key, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeNow = ref.watch(timeNowProvider);
    final mealAdvice = ref.watch(getMealAdviceProvider(meal));

    if (mealAdvice.isLoading || timeNow.isLoading) {
      return const SizedBox.shrink();
    }

    final advice = mealAdvice.asData?.value;
    final timeNowDate = timeNow.asData?.value;
    final recommendedMinutes = advice?.wait?.recommendedMinutes;

    if (advice == null || timeNowDate == null || recommendedMinutes == null) {
      return const SizedBox.shrink();
    }

    final timeDifference = advice.createdAt.difference(timeNowDate);

    logI('timeDifference: $timeDifference');
    logI('recommendedMinutes: $recommendedMinutes');

    final minutesLeft = recommendedMinutes + timeDifference.inMinutes;
    return SizedBox(
      width: 52,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '${minutesLeft}min',
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            color: minutesLeft > 0 ? Colors.black : Colors.red,
          ),
        ),
      ),
    );
  }
}
