import '../models/meal_activity_context.dart';
import '../models/recorded_meal_context.dart';

/// Display relevance windows do not truncate history used by other analyses.
class SelectPrecedingContextUseCase {
  const SelectPrecedingContextUseCase();
  static const mealWindow = Duration(hours: 3);
  static const activityWindow = Duration(hours: 8);

  RecordedMealContext? meal(
    List<RecordedMealContext>? meals,
    DateTime asOf,
    int? currentMealId,
  ) {
    RecordedMealContext? latest;
    for (final entry in meals ?? const <RecordedMealContext>[]) {
      if (entry.mealId == currentMealId ||
          !entry.eatenAt.isBefore(asOf) ||
          asOf.difference(entry.eatenAt) > mealWindow) {
        continue;
      }
      if (latest == null || entry.eatenAt.isAfter(latest.eatenAt)) {
        latest = entry;
      }
    }
    return latest;
  }

  MealActivityContext? activity(
    List<MealActivityContext>? activities,
    DateTime asOf,
  ) {
    final localStart = asOf.toLocal();
    MealActivityContext? latest;
    for (final entry in activities ?? const <MealActivityContext>[]) {
      final at = entry.startedAt.toLocal();
      if (!entry.startedAt.isBefore(asOf) ||
          asOf.difference(entry.startedAt) > activityWindow ||
          at.year != localStart.year ||
          at.month != localStart.month ||
          at.day != localStart.day) {
        continue;
      }
      if (latest == null || entry.startedAt.isAfter(latest.startedAt)) {
        latest = entry;
      }
    }
    return latest;
  }
}
