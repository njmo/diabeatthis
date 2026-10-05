import 'accepted_day_summary.dart';

/// Accepted aggregate facts only; no regenerated history or model conclusions.
class PreviousDaysContext {
  final String startDayKey;
  final String endDayKeyExclusive;
  final List<AcceptedDaySummary> summaries;

  bool get hasPreviousDaySummary {
    final previousKey = DateTime.parse(
      '${endDayKeyExclusive}T00:00:00Z',
    ).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    return summaries.any((s) => s.snapshot.dayKey == previousKey);
  }

  PreviousDaysContext({
    required this.startDayKey,
    required this.endDayKeyExclusive,
    required List<AcceptedDaySummary> summaries,
  }) : summaries = List.unmodifiable(summaries);
}
