import 'package:clock/clock.dart';

import '../../../../core/domain/model/activity.dart';
import '../models/meal_activity_dose_suggestion.dart';
import '../models/meal_activity_windows.dart';

typedef MealDoseActivity = ({
  Activity activity,
  DateTime startedAt,
  DateTime? endedAt,
  bool isUnconfirmed,
});

/// Shared by UI and foreground. Selection uses the latest start among eligible
/// activities; percentages are never summed or converted into reductions.
class GetMealActivityAdviceUseCase {
  const GetMealActivityAdviceUseCase({
    required this.loadWindows,
    required this.loadActivities,
    required this.onError,
    this.loadMealTime,
  });

  final Future<DateTime?> Function(int)? loadMealTime;
  final Future<MealActivityWindows> Function() loadWindows;
  final Future<List<MealDoseActivity>> Function(DateTime, DateTime)
  loadActivities;
  final void Function(Object, StackTrace) onError;

  Future<MealActivityDoseSuggestion?> call({
    DateTime? mealAt,
    int? mealId,
  }) async {
    try {
      mealAt ??= mealId == null ? null : await loadMealTime?.call(mealId);
      mealAt ??= clock.now();
      final windows = await loadWindows();
      if (!windows.isValid) throw ArgumentError('Invalid activity windows');
      final start = mealAt.subtract(Duration(minutes: windows.pastMinutes));
      final end = mealAt.add(Duration(minutes: windows.futureMinutes));
      final activities = await loadActivities(start, end);
      MealDoseActivity? latest;
      MealActivityPhase? phase;
      for (final entry in activities) {
        if (entry.endedAt != null && entry.endedAt!.isBefore(entry.startedAt)) {
          continue;
        }
        final upcoming = entry.startedAt.isAfter(mealAt);
        if (entry.isUnconfirmed && !upcoming) continue;
        final completed =
            entry.endedAt != null && !entry.endedAt!.isAfter(mealAt);
        if (upcoming) {
          if (windows.futureMinutes == 0 || entry.startedAt.isAfter(end)) {
            continue;
          }
        } else if (completed) {
          if (windows.pastMinutes == 0 || entry.endedAt!.isBefore(start)) {
            continue;
          }
        }
        if (latest == null || entry.startedAt.isAfter(latest.startedAt)) {
          latest = entry;
          phase = upcoming
              ? MealActivityPhase.upcoming
              : completed
              ? MealActivityPhase.completed
              : MealActivityPhase.ongoing;
        }
      }
      if (latest == null) return null;
      final percent = phase == MealActivityPhase.completed
          ? latest.activity.percentagePost
          : latest.activity.percentagePre;
      // Zero is the existing default for an unconfigured activity.
      if (percent <= 0 || percent > 100) return null;
      return MealActivityDoseSuggestion(
        dosePercent: percent,
        activityName: latest.activity.name,
        startedAt: latest.startedAt,
        phase: phase!,
      );
    } catch (error, stack) {
      // Missing activity data must not prevent the existing meal flow.
      onError(error, stack);
      return null;
    }
  }
}
