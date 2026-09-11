/// Local calendar boundaries. A finished day excludes the next midnight.
class DayAnalysisWindow {
  final DateTime start;
  final DateTime end;
  final DateTime nightStart;
  final DateTime nightEnd;
  final bool isComplete;

  const DayAnalysisWindow._({
    required this.start,
    required this.end,
    required this.nightStart,
    required this.nightEnd,
    required this.isComplete,
  });

  factory DayAnalysisWindow({required DateTime now, DateTime? date}) {
    final current = now.toLocal();
    final selected = (date ?? current).toLocal();
    final start = DateTime(selected.year, selected.month, selected.day);
    if (start.isAfter(current)) {
      throw ArgumentError.value(date, 'date', 'Cannot analyze a future day');
    }
    // Calendar construction preserves 23/25-hour days across DST changes.
    final nextMidnight = DateTime(start.year, start.month, start.day + 1);
    final complete = !current.isBefore(nextMidnight);
    final end = complete ? nextMidnight : current;
    final morning = DateTime(start.year, start.month, start.day, 6);
    return DayAnalysisWindow._(
      start: start,
      end: end,
      nightStart: DateTime(start.year, start.month, start.day - 1, 22),
      nightEnd: end.isBefore(morning) ? end : morning,
      isComplete: complete,
    );
  }

  /// Existing repositories use inclusive end timestamps.
  DateTime get queryEnd =>
      isComplete ? end.subtract(const Duration(microseconds: 1)) : end;
}
