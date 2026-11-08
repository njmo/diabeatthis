import '../../../core/domain/model/glucose.dart';

/// Time geometry shared by compact glucose charts in both application roles.
class GlucoseChartTimeline {
  GlucoseChartTimeline(List<Glucose> readings, {int maxReadings = 10}) {
    final unique = <int, Glucose>{};
    for (final reading in readings) {
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

  // Five-minute CGM cadence with one minute of timestamp tolerance.
  static const maxConnectedInterval = Duration(minutes: 6);
  late final List<Glucose> values;
  late final List<List<Glucose>> segments;

  double fractionAt(DateTime time) {
    if (values.length < 2) return 0;
    final span = values.last.date.difference(values.first.date).inMicroseconds;
    if (span == 0) return 0;
    return time.difference(values.first.date).inMicroseconds / span;
  }
}
