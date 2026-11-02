import 'package:clock/clock.dart';

import '../../core/domain/model/meal_status_flow.dart';
import '../../core/drift/database_impl.dart';
import 'meal_completion_timing.dart';
import 'pending_meal_completion_requests.dart';

class PendingMealCompletionRecovery {
  const PendingMealCompletionRecovery({
    required this.database,
    required this.requests,
  });

  final DatabaseImpl database;
  final PendingMealCompletionRequests requests;

  /// Fresh confirmations stay with the foreground workflow. Only a late or
  /// unknown eating time needs navigation, even if UI resumes before its reply.
  Future<List<int>> recover({void Function(int mealId)? replayFresh}) async {
    final ready = <int>[];
    for (final mealId in await requests.pending()) {
      final meal = await database.mealDao.getMealById(mealId);
      if (meal == null ||
          (!mealStatusesStartingEating.contains(meal.status) &&
              meal.status != 'eating-extra' &&
              !mealStatusReadyToSummarize(meal.status))) {
        await requests.acknowledge(mealId);
        continue;
      }
      final history = await (database.select(
        database.mealStatusHistory,
      )..where((row) => row.mealId.equals(mealId))).get();
      final timing = MealCompletionTiming.fromHistory(
        history.map(
          (entry) => (
            status: entry.status,
            at: DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
          ),
        ),
        currentStatus: meal.status,
      );
      if (timing.needsTimeConfirmation(clock.now())) {
        ready.add(mealId);
      } else if (mealStatusesStartingEating.contains(meal.status) ||
          meal.status == 'eating-extra') {
        replayFresh?.call(mealId);
      } else {
        await requests.acknowledge(mealId);
      }
    }
    return ready;
  }
}
