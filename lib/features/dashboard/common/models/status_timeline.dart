import 'dart:math' as math;

/// Shared boundary calculations for activity and target status presentation.
class StatusTimeline {
  const StatusTimeline({required this.start, required this.now, this.end});
  final DateTime start;
  final DateTime now;
  final DateTime? end;

  bool get planned => start.isAfter(now);
  int get elapsedMinutes => math.max(0, now.difference(start).inMinutes);
  int get minutesUntilStart => math.max(
    0,
    (start.difference(now).inMicroseconds / Duration.microsecondsPerMinute)
        .ceil(),
  );
  int? get remainingMinutes => end == null
      ? null
      : math.max(
          0,
          (end!.difference(now).inMicroseconds / Duration.microsecondsPerMinute)
              .ceil(),
        );
  double? get progress {
    final total = end?.difference(start).inMicroseconds;
    if (planned || total == null || total <= 0) return null;
    return (now.difference(start).inMicroseconds / total).clamp(0.0, 1.0);
  }
}
