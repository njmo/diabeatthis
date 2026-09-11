import '../../../../common/history/glucose_rise_summary.dart';
import '../../../../common/history/glucose_window_summary.dart';
import '../../../../common/history/has_continuous_history.dart';

bool hasCompleteMealRiseObservation(
  GlucoseRiseSummary rise,
  GlucoseWindowSummary window, {
  required bool complete,
}) =>
    complete &&
    rise.hasObservation &&
    hasContinuousHistory(
      timestamps: window.readings.map((reading) => reading.date),
      start: window.start,
      end: window.end,
    );
