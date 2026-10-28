const activityPreparationLeadTime = Duration(minutes: 90);

/// Calendar arithmetic deliberately preserves local wall time across DST changes.
DateTime activityScheduleStart(DateTime day, int minute) =>
    DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);

DateTime activityScheduleActionAt(
  DateTime start,
  String mode,
  int previousMinute,
) => mode == 'previous_day'
    ? DateTime(
        start.year,
        start.month,
        start.day - 1,
        previousMinute ~/ 60,
        previousMinute % 60,
      )
    : start.subtract(activityPreparationLeadTime);
