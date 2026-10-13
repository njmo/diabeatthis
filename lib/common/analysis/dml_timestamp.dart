/// Uses the same local clock as DML series blocks, with an explicit offset.
/// Keeps exact precision so consumers can still compare instants and durations.
String dmlTimestamp(DateTime instant, {Duration? utcOffset}) {
  final offset = utcOffset ?? instant.toLocal().timeZoneOffset;
  if (offset == Duration.zero) return instant.toUtc().toIso8601String();
  final wall = instant.toUtc().add(offset).toIso8601String();
  return '${wall.substring(0, wall.length - 1)}${dmlUtcOffset(offset)}';
}

String dmlUtcOffset(Duration offset) {
  final minutes = offset.inMinutes;
  final absolute = minutes.abs();
  return '${minutes < 0 ? '-' : '+'}${(absolute ~/ 60).toString().padLeft(2, '0')}:${(absolute % 60).toString().padLeft(2, '0')}';
}
