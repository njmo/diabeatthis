import '../../core/domain/model/glucose.dart';
import 'glucose_window_summary.dart';
import 'has_continuous_history.dart';

/// Time-weighted statistics; samples cover at most five minutes, never gaps.
class GlucosePeriodSummary {
  final GlucoseWindowSummary window;
  final double? mean;

  const GlucosePeriodSummary({required this.window, required this.mean});

  factory GlucosePeriodSummary.calculate(
    Iterable<Glucose> readings,
    DateTime start,
    DateTime end, {
    GlucoseBaselinePolicy baselinePolicy = GlucoseBaselinePolicy.atOrBefore,
  }) {
    final ordered = {
      for (final g in readings)
        if (g.type == GlucoseType.cgm && g.sgv > 0 && !g.date.isAfter(end))
          g.date: g,
    }.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    var weighted = 0.0;
    var covered = 0;
    for (var i = 0; i < ordered.length; i++) {
      final g = ordered[i];
      final from = g.date.isBefore(start) ? start : g.date;
      var until = g.date.add(GlucoseWindowSummary.readingInterval);
      if (i + 1 < ordered.length && ordered[i + 1].date.isBefore(until)) {
        until = ordered[i + 1].date;
      }
      if (until.isAfter(end)) until = end;
      if (!until.isAfter(from)) continue;
      final milliseconds = until.difference(from).inMilliseconds;
      weighted += g.sgv * milliseconds;
      covered += milliseconds;
    }
    return GlucosePeriodSummary(
      window: GlucoseWindowSummary(
        readings: ordered,
        start: start,
        end: end,
        baselinePolicy: baselinePolicy,
      ),
      mean: covered == 0 ? null : weighted / covered,
    );
  }

  /// Sampling completeness is separate from conservative measured coverage.
  /// Small clock drift must not accumulate into an apparent missing reading.
  bool get hasContinuousReadings {
    final readings = window.readings;
    if (!hasContinuousHistory(
      timestamps: readings.map((reading) => reading.date),
      start: window.start,
      end: window.end,
    )) {
      return false;
    }
    final interval = GlucoseWindowSummary.readingInterval;
    final expected =
        window.end.difference(window.start).inMilliseconds ~/
        interval.inMilliseconds;
    if (readings.length >= expected) return true;

    // A shifted stream with small clock drift can lose one boundary sample.
    // Allow that only when the observed mean cadence is still five minutes
    // (within one second), not for a systematically slower stream.
    if (readings.length < 2 || readings.length != expected - 1) return false;
    final span = readings.last.date.difference(readings.first.date);
    return span.inMilliseconds <=
        (readings.length - 1) *
            (interval + const Duration(seconds: 1)).inMilliseconds;
  }

  int get expectedReadingCount {
    final elapsed = window.end.difference(window.start).inMilliseconds;
    return elapsed <= 0
        ? 0
        : (elapsed / GlucoseWindowSummary.readingInterval.inMilliseconds)
              .ceil();
  }

  /// Count expected CGM samples, allowing timestamp jitter and window phase.
  /// Extra clustered readings cannot compensate for gaps elsewhere.
  int get missingReadingCount {
    final expected = expectedReadingCount;
    if (expected == 0 ||
        window.missing == Duration.zero ||
        hasContinuousReadings) {
      return 0;
    }
    final readings = window.readings;
    if (readings.isEmpty) return expected;
    final interval = GlucoseWindowSummary.readingInterval.inMilliseconds;
    const edgeTolerance = Duration(minutes: 5, seconds: 30);
    final leading = readings.first.date.difference(window.start);
    var gaps = leading > edgeTolerance
        ? (leading.inMilliseconds / interval).round()
        : 0;
    for (var i = 1; i < readings.length; i++) {
      final gap = readings[i].date.difference(readings[i - 1].date);
      final missing = (gap.inMilliseconds / interval).round() - 1;
      if (missing > 0) gaps += missing;
    }
    final trailing = window.end.difference(readings.last.date);
    if (trailing > edgeTolerance) {
      gaps += (trailing.inMilliseconds / interval).round() - 1;
    }
    final deficit = expected - readings.length;
    return (gaps > deficit ? gaps : deficit).clamp(0, expected);
  }

  double? get coveragePercent {
    final elapsed = window.end.difference(window.start).inMilliseconds;
    return elapsed <= 0 ? null : window.observed.inMilliseconds / elapsed * 100;
  }
}
