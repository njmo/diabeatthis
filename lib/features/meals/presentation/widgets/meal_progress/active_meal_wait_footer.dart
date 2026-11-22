import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/monitoring/meal_wait_status.dart';
import '../../../../../common/widgets/meal_progress/meal_wait_progress.dart';
import '../../../../../core/domain/model/meal.dart';

final activeMealWaitClockProvider = StreamProvider.autoDispose<DateTime>((
  ref,
) async* {
  yield clock.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => clock.now());
});

class ActiveMealWaitFooter extends ConsumerWidget {
  const ActiveMealWaitFooter({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wait = ref.watch(mealWaitStatusProvider).value;
    if (wait == null || wait.mealId != meal.id) {
      return const SizedBox.shrink();
    }
    final now =
        ref.watch(activeMealWaitClockProvider).asData?.value ?? clock.now();
    return MealWaitProgress(
      remaining: wait.deadline.difference(now),
      total: wait.deadline.difference(wait.startedAt),
      waitingForExtendedCarbs: wait.waitingForExtendedCarbs,
    );
  }
}
