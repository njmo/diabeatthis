import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_window.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'inclusive millisecond repository excludes meals at the following midnight',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final window = DayAnalysisWindow(
        now: DateTime(2026, 9, 11, 12),
        date: DateTime(2026, 9, 9),
      );
      for (final time in [
        window.start,
        window.end.subtract(const Duration(milliseconds: 1)),
        window.end,
      ]) {
        await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: 'Meal',
                plannedAt: time.millisecondsSinceEpoch,
                status: const Value('eaten'),
              ),
            );
      }
      final repository = DayLocalHistoryRepository(db);
      final day = await repository.loadMeals(window.start, window.queryEnd);
      final next = await repository.loadMeals(
        window.end,
        window.end.add(const Duration(hours: 1)),
      );
      expect(day.count, 2);
      expect(next.count, 1);
    },
  );
  test(
    'activity crossing midnight is clipped; one starting at next midnight is excluded',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final start = DateTime(2026, 9, 9);
      final end = DateTime(2026, 9, 10);
      final id = await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Walk',
              percentagePre: 20,
              percentagePost: 10,
            ),
          );
      for (final began in [end.subtract(const Duration(minutes: 30)), end]) {
        await db
            .into(db.activityLog)
            .insert(
              ActivityLogCompanion.insert(
                activityId: id,
                startedAt: began.millisecondsSinceEpoch,
                endedAt: Value(
                  end.add(const Duration(hours: 1)).millisecondsSinceEpoch,
                ),
              ),
            );
      }
      final activities = await DayLocalHistoryRepository(
        db,
      ).loadActivities(start, end);
      expect(activities, hasLength(1));
      expect(activities.single.observedDuration, const Duration(minutes: 30));
      expect(activities.single.ongoing, isTrue);
    },
  );
}
