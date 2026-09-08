import '../../core/domain/model/glucose.dart';

/// A retrospective UI heuristic, not a meal absorption or insulin model.
/// Requires a sustained rise rather than a single noisy CGM interval.
class GlucoseRiseSummary {
  static const minimumRate = 2.0;
  static const minimumDuration = Duration(minutes: 10);
  static const maximumGap = Duration(minutes: 5);

  final DateTime? startedAt;
  final bool hasObservation;

  const GlucoseRiseSummary({
    required this.startedAt,
    required this.hasObservation,
  });

  /// Input must be sorted, deduplicated and restricted to the meal window.
  factory GlucoseRiseSummary.fromReadings(List<Glucose> readings) {
    DateTime? risingSince;
    DateTime? observedSince;
    var hasObservation = false;
    for (var index = 1; index < readings.length; index++) {
      final previous = readings[index - 1];
      final current = readings[index];
      final elapsed = current.date.difference(previous.date);
      if (elapsed <= Duration.zero || elapsed > maximumGap) {
        risingSince = null;
        observedSince = null;
        continue;
      }
      observedSince ??= previous.date;
      if (current.date.difference(observedSince) >= minimumDuration) {
        hasObservation = true;
      }
      final rate =
          (current.sgv - previous.sgv) /
          (elapsed.inMilliseconds / Duration.millisecondsPerMinute);
      if (rate < minimumRate) {
        risingSince = null;
        continue;
      }
      risingSince ??= previous.date;
      if (current.date.difference(risingSince) >= minimumDuration) {
        return GlucoseRiseSummary(startedAt: risingSince, hasObservation: true);
      }
    }
    return GlucoseRiseSummary(startedAt: null, hasObservation: hasObservation);
  }
}
