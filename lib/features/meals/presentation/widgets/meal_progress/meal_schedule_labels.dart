import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';

String mealScheduleDateLabel(
  BuildContext context,
  DateTime? date,
  DateTime now,
) {
  if (date == null) return lang.mealProgressNoDate;
  final local = date.toLocal();
  final today = now.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  if (day == todayDay) return lang.mealProgressToday;
  if (day == DateTime(today.year, today.month, today.day + 1)) {
    return lang.mealProgressTomorrow;
  }
  return mealScheduleFullDate(context, local);
}

String mealScheduleFullDate(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatCompactDate(date.toLocal());

String mealScheduleCompactDateLabel(
  BuildContext context,
  DateTime date,
  DateTime now,
) {
  final local = date.toLocal();
  final today = now.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  if (day == todayDay ||
      day == DateTime(today.year, today.month, today.day + 1)) {
    return mealScheduleDateLabel(context, local, today);
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  return local.year == today.year
      ? DateFormat.MMMd(locale).format(local)
      : DateFormat('dd.MM.yy', locale).format(local);
}

String mealScheduleTime(BuildContext context, DateTime? date) => date == null
    ? '—'
    : MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(date.toLocal()),
        alwaysUse24HourFormat: true,
      );

String mealScheduleLabel(BuildContext context, DateTime? date, DateTime now) =>
    date == null
    ? lang.mealProgressNoDate
    : '${mealScheduleDateLabel(context, date, now)} · ${mealScheduleTime(context, date)}';
