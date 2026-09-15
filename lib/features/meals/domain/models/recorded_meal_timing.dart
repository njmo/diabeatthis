import '../../../../core/domain/model/meal_status_flow.dart';

class RecordedMealTiming {
  final List<({String status, DateTime at})> stages;
  RecordedMealTiming(Iterable<({String status, DateTime at})> stages)
    : stages = List.unmodifiable(stages);
  DateTime? get recordedEatingStartedAt {
    final starts =
        stages
            .where((entry) => mealStatusesStartingEating.contains(entry.status))
            .map((entry) => entry.at)
            .toList()
          ..sort();
    return starts.firstOrNull;
  }

  DateTime? get recordedEatingEndedAt {
    final start = recordedEatingStartedAt;
    if (start == null) return null;
    final ordered = stages.where((entry) => !entry.at.isBefore(start)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    var eatingBeforeBolus = false;
    for (final entry in ordered) {
      if (entry.status == 'eating-then-bolus') eatingBeforeBolus = true;
      if (mealStatusReadyToSummarize(entry.status) ||
          (eatingBeforeBolus && entry.status == 'waiting-for-bolus')) {
        return entry.at;
      }
    }
    return null;
  }

  /// Elapsed status time, distinct from a recorded insulin dose.
  Duration? get recordedWait {
    final start = recordedEatingStartedAt;
    if (start == null) return null;
    final waiting =
        stages
            .where(
              (entry) =>
                  entry.status == 'bolused-waiting' && !entry.at.isAfter(start),
            )
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    return waiting.isEmpty ? null : start.difference(waiting.last.at);
  }
}
