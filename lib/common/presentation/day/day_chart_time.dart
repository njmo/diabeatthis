import '../../../core/domain/model/glucose.dart';

/// Calendar boundaries retain local DST changes instead of adding fixed hours.
DateTime dayChartClock(DateTime day, int hour, {int dayOffset = 0}) => day.isUtc
    ? DateTime.utc(day.year, day.month, day.day + dayOffset, hour)
    : DateTime(day.year, day.month, day.day + dayOffset, hour);

double dayChartFraction(DateTime time, DateTime start, DateTime end) {
  final duration = end.difference(start).inMicroseconds;
  if (duration <= 0) return 0;
  return (time.difference(start).inMicroseconds / duration).clamp(0.0, 1.0);
}

List<(DateTime, String)> dayNightChartTicks(DateTime start, DateTime end) => [
  (start, '${start.hour.toString().padLeft(2, '0')}:00'),
  for (final hour in [0, 2, 4, 6])
    if (dayChartClock(end, hour).hour == hour)
      (dayChartClock(end, hour), '${hour.toString().padLeft(2, '0')}:00'),
];

Iterable<List<Glucose>> dayChartSegments(List<Glucose> readings) sync* {
  var segment = <Glucose>[];
  for (final reading in readings) {
    if (segment.isNotEmpty &&
        reading.date.difference(segment.last.date) >
            const Duration(minutes: 5)) {
      yield segment;
      segment = [];
    }
    segment.add(reading);
  }
  if (segment.isNotEmpty) yield segment;
}
