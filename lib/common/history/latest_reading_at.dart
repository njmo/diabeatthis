/// Returns only a recent recorded value at or before the selected time.
T? latestReadingAt<T>(
  Iterable<T> values,
  DateTime timestamp,
  DateTime Function(T) dateOf, {
  Duration maxAge = const Duration(minutes: 5),
}) {
  T? latest;
  for (final value in values) {
    final date = dateOf(value);
    if (date.isAfter(timestamp) || timestamp.difference(date) > maxAge) {
      continue;
    }
    if (latest == null || date.isAfter(dateOf(latest))) latest = value;
  }
  return latest;
}
