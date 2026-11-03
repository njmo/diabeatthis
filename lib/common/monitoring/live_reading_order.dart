import 'package:clock/clock.dart';

/// Different configured sources may have different delivery delays. Within a
/// source, a delayed sample must never roll the current reading backwards.
/// A future-dated current sample must not prevent recovery after clock skew.
bool acceptsLiveReading({
  required DateTime incomingAt,
  required Object incomingSource,
  required DateTime? currentAt,
  required Object? currentSource,
}) =>
    currentAt == null ||
    incomingSource != currentSource ||
    (currentAt.isAfter(clock.now()) && !incomingAt.isAfter(clock.now())) ||
    !incomingAt.isBefore(currentAt);
