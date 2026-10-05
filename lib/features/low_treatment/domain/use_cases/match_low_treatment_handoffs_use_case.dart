import '../../../../core/domain/model/treat.dart';
import '../models/low_treatment_handoff_pending.dart';

class MatchLowTreatmentHandoffsUseCase {
  const MatchLowTreatmentHandoffsUseCase();

  Map<int, Treat> call({
    required List<LowTreatmentHandoffPending> pending,
    required Map<int, DateTime> recordedAtByMeal,
    required List<Treat> treatments,
    required Set<int> occupiedMealIds,
    required Set<int> occupiedTreatTimes,
    required DateTime now,
  }) {
    final candidates = _uniqueTreatments(treatments, now)
        .where(
          (event) => !occupiedTreatTimes.contains(
            event.createdAt.millisecondsSinceEpoch,
          ),
        )
        .toList(growable: false);
    final candidatesByMeal = <int, List<Treat>>{};
    final mealsByCandidate = <int, List<int>>{};
    for (final item in pending) {
      final recordedAt = recordedAtByMeal[item.mealId];
      if (recordedAt == null || occupiedMealIds.contains(item.mealId)) continue;
      final end = item.savedAt.add(const Duration(minutes: 5));
      final matching = candidates
          .where(
            (event) =>
                !event.createdAt.isBefore(item.savedAt) &&
                !event.createdAt.isAfter(end) &&
                event.carbs.toDouble() == item.expectedCarbs &&
                _localDay(event.createdAt) == _localDay(recordedAt),
          )
          .toList(growable: false);
      candidatesByMeal[item.mealId] = matching;
      for (final event in matching) {
        mealsByCandidate
            .putIfAbsent(event.createdAt.millisecondsSinceEpoch, () => [])
            .add(item.mealId);
      }
    }
    final matches = <int, Treat>{};
    for (final item in pending) {
      final candidates = candidatesByMeal[item.mealId] ?? const [];
      if (candidates.length != 1) continue;
      final candidate = candidates.single;
      if (mealsByCandidate[candidate.createdAt.millisecondsSinceEpoch]
              ?.length ==
          1) {
        matches[item.mealId] = candidate;
      }
    }
    return matches;
  }

  List<Treat> _uniqueTreatments(List<Treat> treatments, DateTime now) {
    final groups = <int, List<Treat>>{};
    for (final event in treatments) {
      if (!event.isValid || event.carbs <= 0 || event.createdAt.isAfter(now)) {
        continue;
      }
      groups
          .putIfAbsent(event.createdAt.millisecondsSinceEpoch, () => [])
          .add(event);
    }
    final unique = <Treat>[];
    for (final events in groups.values) {
      if (events.map((event) => event.carbs).toSet().length != 1) continue;
      final identities = events
          .map((event) => event.externalId)
          .whereType<String>()
          .toSet();
      if (identities.length > 1) continue;
      unique.add(
        events.firstWhere(
          (event) => event.externalId != null,
          orElse: () => events.first,
        ),
      );
    }
    return unique;
  }

  DateTime _localDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
