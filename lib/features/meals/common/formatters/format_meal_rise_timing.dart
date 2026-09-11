import '../../../../common/history/glucose_rise_summary.dart';
import '../../../../common/history/glucose_window_summary.dart';
import '../../../../common/l10n/language.dart';
import '../../../meal_analysis/domain/services/meal_glucose_observation.dart';

/// CGM brackets the observed onset; millisecond offsets are not onset precision.
String formatMealRiseTiming(
  GlucoseRiseSummary rise,
  DateTime mealTime,
  AppLocalizations messages,
) {
  final start = rise.startedAt;
  final end = rise.onsetIntervalEnd;
  if (start == null || end == null) return '—';
  int minutes(DateTime time) =>
      (time.difference(mealTime).inMilliseconds /
              Duration.millisecondsPerMinute)
          .round();
  return messages.mealResponseRiseInterval(minutes(start), minutes(end));
}

/// Missing samples must not be presented as evidence that no rise occurred.
String formatMealRiseAbsence(
  GlucoseRiseSummary rise,
  GlucoseWindowSummary window,
  AppLocalizations messages, {
  required bool complete,
}) => hasCompleteMealRiseObservation(rise, window, complete: complete)
    ? messages.mealResponseNoRise
    : messages.mealResponseMissing;
