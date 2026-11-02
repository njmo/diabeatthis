import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/domain/model/meal_status_flow.dart';

class MealScheduleGroup {
  const MealScheduleGroup({required this.date, required this.meals});

  final DateTime? date;
  final List<Meal> meals;
}

List<MealScheduleGroup> mealScheduleGroups(Iterable<Meal> meals) {
  final byDate = <DateTime?, List<Meal>>{};
  for (final meal in meals) {
    if (mealStatusBlocksAnotherMealActivation(meal.status) ||
        mealStatusReadyToSummarize(meal.status) ||
        const {'summarized', 'skipped', 'interrupted'}.contains(meal.status)) {
      continue;
    }
    final scheduled = meal.plannedAt?.toLocal();
    final day = scheduled == null
        ? null
        : DateTime(scheduled.year, scheduled.month, scheduled.day);
    byDate.putIfAbsent(day, () => []).add(meal);
  }
  final dates = byDate.keys.toList()
    ..sort((a, b) {
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return a.compareTo(b);
    });
  return [
    for (final date in dates)
      MealScheduleGroup(
        date: date,
        meals: byDate[date]!
          ..sort(
            (a, b) => (a.plannedAt?.millisecondsSinceEpoch ?? 0).compareTo(
              b.plannedAt?.millisecondsSinceEpoch ?? 0,
            ),
          ),
      ),
  ];
}
