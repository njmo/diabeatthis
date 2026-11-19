import '../../../core/domain/model/glucose.dart';

/// Time geometry shared by compact glucose charts in both application roles.
class GlucoseChartTimeline {
  GlucoseChartTimeline(
    List<Glucose> readings, {
    int maxReadings = 10,
    DateTime? windowEnd,
    Duration? window,
  }) : _windowEnd = windowEnd,
       _windowStart = windowEnd?.subtract(window ?? const Duration(hours: 2)) {
    final unique = <int, Glucose>{};
    for (final reading in readings) {
      if (_windowStart != null &&
          (reading.date.isBefore(_windowStart) ||
              reading.date.isAfter(_windowEnd!))) {
        continue;
      }
      unique[reading.date.millisecondsSinceEpoch] = reading;
    }
    final ordered = unique.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    values = ordered.length <= maxReadings
        ? ordered
        : ordered.sublist(ordered.length - maxReadings);
    segments = [];
    for (final value in values) {
      if (segments.isEmpty ||
          value.date.difference(segments.last.last.date) >
              maxConnectedInterval) {
        segments.add([value]);
      } else {
        segments.last.add(value);
      }
    }
  }

  // Five-minute CGM cadence with two minutes of timestamp tolerance. A delayed
  // sample just beyond six minutes must not look like a missing full reading.
  static const maxConnectedInterval = Duration(minutes: 7);
  late final List<Glucose> values;
  late final List<List<Glucose>> segments;
  final DateTime? _windowStart, _windowEnd;

  double fractionAt(DateTime time) {
    if (_windowStart != null) {
      return time.difference(_windowStart).inMicroseconds /
          _windowEnd!.difference(_windowStart).inMicroseconds;
    }
    if (values.length < 2) return 0;
    final span = values.last.date.difference(values.first.date).inMicroseconds;
    if (span == 0) return 0;
    return time.difference(values.first.date).inMicroseconds / span;
  }
}
