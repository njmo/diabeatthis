import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meal_analysis/data/repositories/meal_context_local_history_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 29, 13);
  for (final scenario in [
    (name: 'session override', scheduled: true, duration: 45, expected: 45),
    (
      name: 'session without an end',
      scheduled: true,
      duration: null,
      expected: null,
    ),
    (
      name: 'activity without a scheduled session',
      scheduled: false,
      duration: null,
      expected: 60,
    ),
  ]) {
    test('meal context respects ${scenario.name}', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final activityId = await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Run',
              percentagePre: 0,
              percentagePost: 0,
              durationMinutes: const Value(60),
            ),
          );
      final logId = await db
          .into(db.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activityId,
              startedAt: start.millisecondsSinceEpoch,
              createdAt: Value(start.millisecondsSinceEpoch),
            ),
          );
      if (scenario.scheduled) {
        await db
            .into(db.activityOccurrence)
            .insert(
              ActivityOccurrenceCompanion.insert(
                activityId: activityId,
                startedAt: start.millisecondsSinceEpoch,
                durationMinutes: Value(scenario.duration),
                actionAt: start
                    .subtract(const Duration(hours: 1))
                    .millisecondsSinceEpoch,
                confirmationMode: 'automatic',
                status: const Value('planned'),
                activityLogId: Value(logId),
              ),
            );
      }

      final activities = await MealContextLocalHistoryRepository(db)
          .loadActivities(
            start.subtract(const Duration(hours: 1)),
            start.add(const Duration(hours: 1)),
            start.add(const Duration(minutes: 30)),
          );

      expect(activities.single.plannedDurationMinutes, scenario.expected);
      expect(activities.single.startedAt, start);
      expect(activities.single.endedAt, isNull);
    });
  }
}
