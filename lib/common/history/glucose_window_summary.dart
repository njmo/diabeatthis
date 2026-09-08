import '../../core/domain/model/glucose.dart';

/// A reading represents at most one CGM interval. Missing time stays unknown.
class GlucoseWindowSummary {
  static const readingInterval = Duration(minutes: 5);

  final DateTime start;
  final DateTime end;
  final List<Glucose> readings;
  final Glucose? baseline;
  final Duration belowRange;
  final Duration inRange;
  final Duration aboveRange;

  const GlucoseWindowSummary._({
    required this.start,
    required this.end,
    required this.readings,
    required this.baseline,
    required this.belowRange,
    required this.inRange,
    required this.aboveRange,
  });

  factory GlucoseWindowSummary({
    required Iterable<Glucose> readings,
    required DateTime start,
    required DateTime end,
  }) {
    final byTime = {
      for (final reading in readings)
        if (reading.sgv > 0 && !reading.date.isAfter(end))
          reading.date: reading,
    };
    final ordered = byTime.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final window = ordered.where((g) => !g.date.isBefore(start)).toList();
    final baseline = ordered
        .where(
          (g) =>
              !g.date.isAfter(start) &&
              start.difference(g.date) <= readingInterval,
        )
        .lastOrNull;
    var below = Duration.zero;
    var within = Duration.zero;
    var above = Duration.zero;
    for (var index = 0; index < ordered.length; index++) {
      final reading = ordered[index];
      final from = reading.date.isBefore(start) ? start : reading.date;
      var until = reading.date.add(readingInterval);
      if (index + 1 < ordered.length &&
          ordered[index + 1].date.isBefore(until)) {
        until = ordered[index + 1].date;
      }
      if (end.isBefore(until)) until = end;
      if (!until.isAfter(from)) continue;
      final duration = until.difference(from);
      if (reading.sgv < 70) {
        below += duration;
      } else if (reading.sgv > 180) {
        above += duration;
      } else {
        within += duration;
      }
    }
    return GlucoseWindowSummary._(
      start: start,
      end: end,
      readings: List.unmodifiable(window),
      baseline: baseline,
      belowRange: below,
      inRange: within,
      aboveRange: above,
    );
  }

  Duration get observed => belowRange + inRange + aboveRange;
  Duration get missing {
    final duration = end.difference(start) - observed;
    return duration.isNegative ? Duration.zero : duration;
  }

  double? percent(Duration duration) => observed == Duration.zero
      ? null
      : duration.inMilliseconds / observed.inMilliseconds * 100;

  Glucose? get peak => readings.isEmpty
      ? null
      : readings.reduce((a, b) => a.sgv >= b.sgv ? a : b);
  Glucose? get minimum => readings.isEmpty
      ? null
      : readings.reduce((a, b) => a.sgv <= b.sgv ? a : b);
  Glucose? get last => readings.lastOrNull;

  /// A stale last reading is not a measurement of the end of observation.
  Glucose? get endpoint {
    final reading = last;
    return reading != null && end.difference(reading.date) <= readingInterval
        ? reading
        : null;
  }

  int? get endDelta => baseline == null || endpoint == null
      ? null
      : endpoint!.sgv - baseline!.sgv;

  Glucose? get firstAboveRange =>
      readings.where((g) => g.sgv > 180).firstOrNull;

  /// This is an observed return, not a claim that glucose stayed in range.
  Glucose? get firstReturnAfterPeak {
    final highest = peak;
    if (highest == null || highest.sgv <= 180) return null;
    return readings
        .where(
          (g) => g.date.isAfter(highest.date) && g.sgv >= 70 && g.sgv <= 180,
        )
        .firstOrNull;
  }
}
