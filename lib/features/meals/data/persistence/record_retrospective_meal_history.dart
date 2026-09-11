import 'package:drift/drift.dart';

import '../../../../core/drift/database_impl.dart';
import '../../../../core/logger/logger.dart';
import '../models/retrospective_meal_timing.dart';

/// Call inside the transaction that creates or confirms the meal.
Future<void> recordRetrospectiveMealHistory(
  DatabaseImpl db,
  int mealId,
  RetrospectiveMealTiming timing,
  DateTime startedAt, {
  bool summarize = true,
}) async {
  final history = timing.history(startedAt);
  final previous = await db.mealAdvisorResultDao.getMealAdvisorResult(mealId);
  if (previous == null) {
    await db
        .into(db.mealAdvisorResult)
        .insert(
          MealAdvisorResultCompanion.insert(
            mealId: Value(mealId),
            version: const Value(null),
            createdAt: Value(history.values.first.millisecondsSinceEpoch),
            updatedAt: Value(history.values.first.millisecondsSinceEpoch),
            result: 'manual',
            initialWaitTime: timing.choice.waitMinutes,
            finalWaitTime: timing.choice.waitMinutes,
            waitTimeIgnored: false,
          ),
        );
  } else {
    // Keep the original suggestion; only record how long the user actually waited.
    await db.mealAdvisorResultDao.updateAdvisorResultWaitOutcome(
      mealId: mealId,
      finalWaitTime: timing.choice.waitMinutes,
      waitTimeIgnored:
          previous.result != 'manual' &&
          timing.choice.waitMinutes < previous.initialWaitTime,
    );
  }
  Log.i(
    'MealReviewHistory',
    'Advisor outcome saved: mealId=$mealId, existing=${previous != null}, summarize=$summarize',
  );
  for (final event in history.entries) {
    if (!summarize && event.key == 'summarized') continue;
    Log.i(
      'MealReviewHistory',
      'Writing status: mealId=$mealId, status=${event.key}, occurredAt=${event.value}',
    );
    await db.mealDao.updateMealStatus(
      mealId,
      event.key,
      occurredAt: event.value,
    );
  }
}
