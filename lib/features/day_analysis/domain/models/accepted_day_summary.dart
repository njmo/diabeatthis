import 'day_summary_snapshot.dart';

class AcceptedDaySummary {
  final DateTime acceptedAt;
  final DaySummarySnapshot snapshot;
  final int utcOffsetMinutes;
  AcceptedDaySummary({
    required this.acceptedAt,
    required this.snapshot,
    int? utcOffsetMinutes,
  }) : utcOffsetMinutes =
           utcOffsetMinutes ?? acceptedAt.timeZoneOffset.inMinutes;

  DateTime get displayAcceptedAt =>
      acceptedAt.toUtc().add(Duration(minutes: utcOffsetMinutes));
}
