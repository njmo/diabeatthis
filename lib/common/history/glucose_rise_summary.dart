import '../../core/domain/model/glucose.dart';

/// A retrospective UI heuristic, not a meal absorption or insulin model.
/// Confirms a rise across several CGM intervals, rather than one abrupt jump.
class GlucoseRiseSummary {
  static const minimumRate = 1.5;
  static const minimumIntervalRate = 1.0;
  static const minimumDuration = Duration(minutes: 10);
  static const maximumDuration = Duration(minutes: 15);
  static const cadenceTolerance = Duration(seconds: 30);
  static const maximumGap = Duration(minutes: 6);

  final DateTime? startedAt;

  /// End of the first rising sample interval, not the confirmation time.
  final DateTime? onsetIntervalEnd;
  final bool hasObservation;

  const GlucoseRiseSummary({
    required this.startedAt,
    this.onsetIntervalEnd,
    required this.hasObservation,
  });

  /// Input must be sorted, deduplicated and restricted to the meal window.
  factory GlucoseRiseSummary.fromReadings(List<Glucose> readings) {
    var risingStart = 0;
    DateTime? observedSince;
    var hasObservation = false;
    for (var index = 1; index < readings.length; index++) {
      final previous = readings[index - 1];
      final current = readings[index];
      final elapsed = current.date.difference(previous.date);
      if (elapsed <= Duration.zero || elapsed > maximumGap) {
        risingStart = index;
        observedSince = null;
        continue;
      }
      observedSince ??= previous.date;
      if (current.date.difference(observedSince) >=
          minimumDuration - cadenceTolerance) {
        hasObservation = true;
      }
      final rate =
          (current.sgv - previous.sgv) /
          (elapsed.inMilliseconds / Duration.millisecondsPerMinute);
      // A plateau, fall or weak drift interrupts the candidate. In particular,
      // one large jump followed by a nearly flat trace cannot establish onset.
      if (rate < minimumIntervalRate) {
        risingStart = index;
        continue;
      }
      while (risingStart < index &&
          current.date.difference(readings[risingStart].date) >
              maximumDuration + cadenceTolerance) {
        risingStart++;
      }
      // Check short windows, so an earlier slow drift cannot dilute a later
      // acceleration. Require at least two intervals, even with timestamp jitter.
      for (var start = risingStart; start <= index - 2; start++) {
        final first = readings[start];
        final duration = current.date.difference(first.date);
        if (duration < minimumDuration - cadenceTolerance) break;
        final averageRate =
            (current.sgv - first.sgv) /
            (duration.inMilliseconds / Duration.millisecondsPerMinute);
        if (averageRate >= minimumRate) {
          return GlucoseRiseSummary(
            startedAt: first.date,
            onsetIntervalEnd: readings[start + 1].date,
            hasObservation: true,
          );
        }
      }
    }
    return GlucoseRiseSummary(startedAt: null, hasObservation: hasObservation);
  }
}
