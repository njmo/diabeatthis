import '../../core/domain/model/glucose.dart';
import 'glucose_window_summary.dart';

/// Time-weighted statistics; samples cover at most five minutes, never gaps.
class GlucosePeriodSummary {
  final GlucoseWindowSummary window;
  final double? mean;

  const GlucosePeriodSummary({required this.window, required this.mean});

  factory GlucosePeriodSummary.calculate(
    Iterable<Glucose> readings,
    DateTime start,
    DateTime end,
  ) {
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
      window: GlucoseWindowSummary(readings: ordered, start: start, end: end),
      mean: covered == 0 ? null : weighted / covered,
    );
  }

  double? get coveragePercent {
    final elapsed = window.end.difference(window.start).inMilliseconds;
    return elapsed <= 0 ? null : window.observed.inMilliseconds / elapsed * 100;
  }
}
