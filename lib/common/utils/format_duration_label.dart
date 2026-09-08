String formatDurationLabel(Duration duration) {
  final minutes = duration.inMinutes.abs();
  if (minutes == 0 && duration != Duration.zero) return '<1 min';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return hours == 0
      ? '$minutes min'
      : remainder == 0
      ? '$hours h'
      : '$hours h $remainder min';
}
