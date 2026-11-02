class TimeSeriesCoverage {
  const TimeSeriesCoverage({required this.available, required this.expected});

  factory TimeSeriesCoverage.fromTimestamps({
    required Iterable<DateTime> timestamps,
    required DateTime start,
    required DateTime end,
    Duration interval = const Duration(minutes: 5),
  }) {
    final duration = end.difference(start).inMilliseconds;
    if (duration <= 0) {
      return const TimeSeriesCoverage(available: 0, expected: 0);
    }
    final expected = (duration / interval.inMilliseconds).ceil();
    // Ignore duplicate timestamps and readings outside the requested range.
    final readings = timestamps
        .where((date) => !date.isBefore(start) && date.isBefore(end))
        .map((date) => date.millisecondsSinceEpoch)
        .toSet();
    return TimeSeriesCoverage(available: readings.length, expected: expected);
  }

  final int available;
  final int expected;

  int get missing => (expected - available).clamp(0, expected);

  /// Presentation threshold: strictly more than 10% of expected samples.
  bool get hasSignificantMissing => expected > 0 && missing * 10 > expected;

  bool get isBelowHalf => expected > 0 && available * 2 < expected;
}
