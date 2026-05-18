class CollectorNextReadingHelper {
  const CollectorNextReadingHelper();

  static const expectedInterval = Duration(minutes: 5, seconds: 10);
  static const staleHistoryThreshold = Duration(minutes: 15);

  DateTime nextExpectedAt({
    required DateTime readingDate,
    required DateTime now,
  }) {
    if (now.difference(readingDate) <= staleHistoryThreshold) {
      return readingDate.add(expectedInterval);
    }

    return nextWindowAfter(readingDate: readingDate, now: now);
  }

  DateTime nextWindowAfter({
    required DateTime readingDate,
    required DateTime now,
  }) {
    final elapsed = now.difference(readingDate);
    if (elapsed <= Duration.zero) {
      return readingDate.add(expectedInterval);
    }

    final intervalSeconds = expectedInterval.inSeconds;
    final intervalsElapsed = elapsed.inSeconds ~/ intervalSeconds + 1;

    return readingDate.add(
      Duration(seconds: intervalSeconds * intervalsElapsed),
    );
  }
}
