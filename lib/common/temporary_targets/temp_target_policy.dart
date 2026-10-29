class TempTargetPolicy {
  const TempTargetPolicy._();

  static const mealTarget = 90;
  static const mealDuration = 45;
  static const activityTarget = 140;
  static const manualActivityDuration = 90;
  static const initialManualActivityCoverage = Duration(minutes: 30);
  static const activityLeadTime = Duration(hours: 1);
  static const renewalLeadTime = Duration(minutes: 10);

  static bool acceptsActivityTargetValue(int target) =>
      target >= activityTarget;

  static int minutesUntil(DateTime now, DateTime end) =>
      (end.difference(now).inMilliseconds / Duration.millisecondsPerMinute)
          .ceil();
}
