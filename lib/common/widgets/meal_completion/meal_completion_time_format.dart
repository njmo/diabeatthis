import 'package:intl/intl.dart';

/// Formats a meal time without ambiguity for imported historical meals:
/// time only for today, day and month this year, full date otherwise.
String formatMealCompletionTime(
  DateTime value,
  DateTime now,
  String locale, {
  bool omitTodayDate = false,
}) {
  final today =
      value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
  final pattern = omitTodayDate && today
      ? 'HH:mm'
      : value.year == now.year
      ? 'd MMM HH:mm'
      : 'd MMM yyyy HH:mm';
  return DateFormat(pattern, locale).format(value);
}
