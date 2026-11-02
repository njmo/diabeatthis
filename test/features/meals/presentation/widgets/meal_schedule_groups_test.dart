import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_progress/meal_schedule_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps every planned date and orders times within each day', () {
    final groups = mealScheduleGroups([
      Meal(
        id: 3,
        name: 'Later',
        status: 'planned',
        plannedAt: DateTime(2026, 11, 4, 12),
      ),
      Meal(
        id: 2,
        name: 'Lunch',
        status: 'planned',
        plannedAt: DateTime(2026, 11, 2, 13),
      ),
      Meal(
        id: 1,
        name: 'Breakfast',
        status: 'planned',
        plannedAt: DateTime(2026, 11, 2, 8),
      ),
      const Meal(id: 4, name: 'Unscheduled', status: 'planned'),
    ]);

    expect(groups.map((group) => group.date), [
      DateTime(2026, 11, 2),
      DateTime(2026, 11, 4),
      null,
    ]);
    expect(groups.first.meals.map((meal) => meal.id), [1, 2]);
  });

  test('does not duplicate active, summary, or finished meals in the plan', () {
    const statuses = [
      'planned',
      'waiting-for-bolus',
      'bolused-waiting',
      'eating',
      'eating-then-bolus',
      'eating-extra',
      'eaten',
      'eaten-extra',
      'eaten-bolused',
      'summarized',
      'skipped',
      'interrupted',
    ];
    final groups = mealScheduleGroups([
      for (var i = 0; i < statuses.length; i++)
        Meal(
          id: i,
          name: statuses[i],
          status: statuses[i],
          plannedAt: DateTime(2026, 11, 1),
        ),
    ]);

    expect(groups.single.meals.single.status, 'planned');
  });
}
