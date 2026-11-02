import '../../features/meals/domain/models/recorded_meal_timing.dart';

class MealCompletionTiming {
  const MealCompletionTiming({
    required this.startedAt,
    required this.endedAt,
    required this.endStatus,
    this.isAddOn = false,
  });

  factory MealCompletionTiming.fromHistory(
    Iterable<({String status, DateTime at})> history, {
    String? currentStatus,
  }) {
    final recorded = RecordedMealTiming(history);
    if (currentStatus == 'eating-extra' || currentStatus == 'eaten-extra') {
      final starts =
          recorded.stages
              .where((entry) => entry.status == 'eating-extra')
              .map((entry) => entry.at)
              .toList()
            ..sort();
      final start = starts.lastOrNull;
      final ends =
          recorded.stages
              .where(
                (entry) =>
                    entry.status == 'eaten-extra' &&
                    (start == null || !entry.at.isBefore(start)),
              )
              .map((entry) => entry.at)
              .toList()
            ..sort();
      return MealCompletionTiming(
        startedAt: start,
        endedAt: ends.firstOrNull,
        endStatus: ends.isEmpty ? null : 'eaten-extra',
        isAddOn: true,
      );
    }
    if (currentStatus == 'eaten-bolused') {
      final waiting =
          recorded.stages
              .where((entry) => entry.status == 'waiting-for-bolus')
              .map((entry) => entry.at)
              .toList()
            ..sort();
      final eatingEnds =
          recorded.stages
              .where((entry) => entry.status == 'eaten')
              .map((entry) => entry.at)
              .toList()
            ..sort();
      return MealCompletionTiming(
        startedAt: recorded.recordedEatingStartedAt,
        endedAt: waiting.firstOrNull ?? eatingEnds.firstOrNull,
        endStatus: waiting.isNotEmpty ? 'waiting-for-bolus' : 'eaten',
      );
    }
    final end = recorded.recordedEatingEndedAt;
    final matching = end == null
        ? null
        : recorded.stages
              .where((entry) => entry.at == end)
              .where(
                (entry) => const {
                  'eaten',
                  'eaten-extra',
                  'eaten-bolused',
                  'waiting-for-bolus',
                }.contains(entry.status),
              )
              .firstOrNull;
    return MealCompletionTiming(
      startedAt: recorded.recordedEatingStartedAt,
      endedAt: end,
      endStatus: matching?.status,
    );
  }

  static const lateConfirmationThreshold = Duration(minutes: 60);

  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endStatus;
  final bool isAddOn;

  bool needsTimeConfirmation(DateTime now) {
    final start = startedAt;
    if (start == null) return true;
    return (endedAt ?? now).difference(start) >= lateConfirmationThreshold;
  }

  /// Reporting delay is measured at entry, even when the actual end is earlier.
  bool isLateReport(DateTime now) {
    final start = startedAt;
    return start == null || now.difference(start) >= lateConfirmationThreshold;
  }

  bool canAssumeEndedNow(DateTime now) =>
      startedAt != null && !isLateReport(now) && isValidEnd(now, now);

  bool isValidEnd(DateTime? end, DateTime now) =>
      end != null &&
      !end.isAfter(now) &&
      (startedAt == null || !end.isBefore(startedAt!));
}
