import '../../core/domain/model/glucose.dart';

/// Retrospective selection only; never use future readings for live decisions.
Glucose? nearestCgmReading(
  Iterable<Glucose> readings,
  DateTime timestamp, {
  Duration maxDistance = const Duration(minutes: 5),
}) {
  Glucose? nearest;
  for (final reading in readings) {
    if (reading.type != GlucoseType.cgm || reading.sgv <= 0) continue;
    final distance = reading.date.difference(timestamp).abs();
    if (distance > maxDistance) continue;
    if (nearest == null ||
        distance < nearest.date.difference(timestamp).abs() ||
        (distance == nearest.date.difference(timestamp).abs() &&
            reading.date.isBefore(nearest.date))) {
      nearest = reading;
    }
  }
  return nearest;
}
