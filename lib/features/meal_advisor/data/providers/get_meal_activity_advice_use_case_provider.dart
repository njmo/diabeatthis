import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/meal/meal_add_on_bolus_context.dart';
import '../../../../common/meal/meal_completion_timing.dart';
import '../../../../core/drift/mappers/activity_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../domain/models/meal_activity_windows.dart';
import '../../domain/use_cases/get_meal_activity_advice_use_case.dart';
import 'meal_activity_windows_provider.dart';

final getMealActivityAdviceUseCaseProvider = Provider<GetMealActivityAdviceUseCase>((
  ref,
) {
  return GetMealActivityAdviceUseCase(
    loadMealTime: (mealId) async {
      if (!ref.exists(databaseProvider)) return null;
      final db = ref.read(databaseProvider);
      if (!db.hasOpened) return null;
      final meal = await db.mealDao.getMealById(mealId);
      final addOn = MealAddOnBolusContext.decode(meal?.addOnBolusContext);
      if (addOn?.eatingStartedAt != null) return addOn!.eatingStartedAt;
      final history = await (db.select(
        db.mealStatusHistory,
      )..where((r) => r.mealId.equals(mealId))).get();
      return MealCompletionTiming.fromHistory(
        history.map(
          (r) => (
            status: r.status,
            at: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
          ),
        ),
        currentStatus: meal?.status,
      ).startedAt;
    },
    loadWindows: () async {
      if (!ref.exists(databaseProvider) ||
          !ref.read(databaseProvider).hasOpened) {
        return const MealActivityWindows();
      }
      return ref.read(mealActivityWindowsProvider.future);
    },
    onError: (error, stack) => Log.e(
      'MealActivityAdvice',
      'Could not load activity advice',
      error: error,
      stackTrace: stack,
    ),
    loadActivities: (start, end) async {
      // Optional advice uses the active app database; it must not start a
      // separate connection when no meal/history source has been initialized.
      if (!ref.exists(databaseProvider)) return [];
      final db = ref.read(databaseProvider);
      if (!db.hasOpened) return [];
      return db.transaction(() async {
        final logs = await db.activityDao.getActivityLogsOverlapping(
          start.subtract(const Duration(milliseconds: 1)),
          end.add(const Duration(milliseconds: 1)),
        );
        final query =
            db.select(db.activityOccurrence).join([
              innerJoin(
                db.activity,
                db.activity.id.equalsExp(db.activityOccurrence.activityId),
              ),
            ])..where(
              db.activityOccurrence.startedAt.isBetweenValues(
                    start.millisecondsSinceEpoch,
                    end.millisecondsSinceEpoch,
                  ) &
                  db.activityOccurrence.activityLogId.isNull() &
                  db.activityOccurrence.status.isIn(['pending', 'planned']),
            );
        final planned = await query.get();
        return [
          for (final row in logs)
            if (![
              'skipped',
              'deleted',
              'missed',
              'cancelled',
            ].contains(row.occurrence?.status))
              (
                isUnconfirmed: false,
                activity: row.activity.toDomain(),
                startedAt: DateTime.fromMillisecondsSinceEpoch(
                  row.log.startedAt,
                ),
                endedAt: row.log.endedAt == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(row.log.endedAt!),
              ),
          for (final row in planned)
            (
              isUnconfirmed: true,
              activity: row.readTable(db.activity).toDomain(),
              startedAt: DateTime.fromMillisecondsSinceEpoch(
                row.readTable(db.activityOccurrence).startedAt,
              ),
              // Unconfirmed occurrences are plans, never proof of completed exercise.
              endedAt: null,
            ),
        ];
      });
    },
  );
});
