import 'package:diabeatthis/features/meal_analysis/domain/models/meal_activity_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros;

MealActivityContext activityAt(int id, DateTime at) => MealActivityContext(
  logId: id,
  name: 'Activity $id',
  startedAt: at,
  endedAt: null,
  recordedAt: at.subtract(const Duration(hours: 1)),
  plannedDurationMinutes: 30,
  percentagePre: 100,
  percentagePost: 100,
);

void main() {
  test(
    'chooses latest activity within eight hours and excludes upcoming plans',
    () async {
      final context = await builder(
        activities: [
          activityAt(1, cutoff.subtract(const Duration(hours: 9))),
          activityAt(2, cutoff.subtract(const Duration(hours: 8))),
          activityAt(3, cutoff.subtract(const Duration(hours: 1))),
          activityAt(4, cutoff.add(const Duration(hours: 1))),
        ],
      )(asOf: cutoff, macros: macros);
      expect(context.recentPrecedingActivity?.logId, 3);
    },
  );
  test(
    'excludes previous calendar day even when less than eight hours ago',
    () async {
      final earlyMeal = DateTime(cutoff.year, cutoff.month, cutoff.day, 2);
      final context = await builder(
        activities: [
          activityAt(1, earlyMeal.subtract(const Duration(hours: 3))),
        ],
      )(asOf: earlyMeal, macros: macros);
      expect(context.recentPrecedingActivity, isNull);
    },
  );
}
