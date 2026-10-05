import '../models/accepted_day_summary.dart';
import '../models/previous_days_context.dart';

class LoadPreviousDaysContextUseCase {
  final Future<List<AcceptedDaySummary>> Function(String, String) loadAccepted;
  const LoadPreviousDaysContextUseCase({required this.loadAccepted});

  Future<PreviousDaysContext> call(String dayKey) async {
    // Calendar arithmetic: a DST transition must not shift the requested dates.
    final day = DateTime.parse('${dayKey}T00:00:00Z');
    final start = day
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);
    final summaries =
        (await loadAccepted(start, dayKey))
            .where(
              (s) =>
                  s.snapshot.dayKey.compareTo(start) >= 0 &&
                  s.snapshot.dayKey.compareTo(dayKey) < 0,
            )
            .toList()
          ..sort((a, b) => a.snapshot.dayKey.compareTo(b.snapshot.dayKey));
    return PreviousDaysContext(
      startDayKey: start,
      endDayKeyExclusive: dayKey,
      summaries: summaries,
    );
  }
}
