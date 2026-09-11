/// Tests sampling continuity, not measured time-in-range coverage.
/// A regular five-minute stream may have timestamp jitter and arbitrary phase
/// at either edge. Counts alone cannot distinguish a stream from clustered data.
bool hasContinuousHistory({
  required Iterable<DateTime> timestamps,
  required DateTime start,
  required DateTime end,
  Duration maximumGap = const Duration(minutes: 6),
  Duration edgeTolerance = const Duration(minutes: 5, seconds: 30),
}) {
  if (!end.isAfter(start)) return false;
  final ordered =
      timestamps
          .where((time) => !time.isBefore(start) && !time.isAfter(end))
          .toSet()
          .toList()
        ..sort();
  if (ordered.isEmpty ||
      ordered.first.difference(start) > edgeTolerance ||
      end.difference(ordered.last) > edgeTolerance) {
    return false;
  }
  for (var i = 1; i < ordered.length; i++) {
    if (ordered[i].difference(ordered[i - 1]) > maximumGap) return false;
  }
  return true;
}
