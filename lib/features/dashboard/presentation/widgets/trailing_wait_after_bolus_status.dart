import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as ref;

import '../../../../app/router/providers/flutter_local_notifications_plugin_provider.dart';
import '../../data/providers/meal_advisor_result_provider.dart';
import '../../data/providers/time_now_provider.dart';

import 'package:timezone/timezone.dart' as tz;


class TrailingWaitAfterBolusStatus extends HookConsumerWidget {
  final meal;
  const TrailingWaitAfterBolusStatus({super.key, required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeNow = ref.watch(timeNowProvider);
    final mealAdvice = ref.watch(getMealAdviceProvider(meal));

    if(mealAdvice.isLoading)
      return const SizedBox.shrink();

    if(mealAdvice.asData?.value == null)
      return const SizedBox.shrink();

    final timeStarted = mealAdvice.asData?.value!.created_at!;
    final timeNowDate = timeNow.asData!.value;
    final timeDifference = timeStarted!.difference(timeNowDate);
    final recommendedMinutes =
        mealAdvice.asData?.value?.wait!.recommendedMinutes;

    print('timeDifference: $timeDifference');
    print('recommendedMinutes: $recommendedMinutes');

    final minutesLeft = (recommendedMinutes ?? 0) + timeDifference.inMinutes;
    return Text(
      '${minutesLeft}min',
      style: TextStyle(
        fontSize: 12,
        color: minutesLeft > 0 ? Colors.black : Colors.red,
      ),
    );
  }

}
