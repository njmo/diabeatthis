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
  }) =>
      select(
        pending: pending,
        recordedAtByMeal: recordedAtByMeal,
        treatments: treatments,
        occupiedMealIds: occupiedMealIds,
        occupiedTreatTimes: occupiedTreatTimes,
        now: now,
      ).map(
        (id, entries) => MapEntry(
          id,
          Treat(
            externalId: entries.length == 1 ? entries.single.externalId : null,
            createdAt: entries.last.createdAt,
            carbs: entries.fold(0, (sum, entry) => sum + entry.carbs),
          ),
        ),
      );

  /// Only receipts attributable to one pending intake may contribute to its sum.
  Map<int, List<Treat>> select({
    required List<LowTreatmentHandoffPending> pending,
    required Map<int, DateTime> recordedAtByMeal,
    required List<Treat> treatments,
    required Set<int> occupiedMealIds,
    required Set<int> occupiedTreatTimes,
    required DateTime now,
  }) {
    final candidates =
        _uniqueTreatments(treatments, now)
            .where(
              (event) => !occupiedTreatTimes.contains(
                event.createdAt.millisecondsSinceEpoch,
              ),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final eligible = pending
        .where(
          (item) =>
              recordedAtByMeal.containsKey(item.mealId) &&
              !occupiedMealIds.contains(item.mealId) &&
              item.expectedCarbs.isFinite &&
              item.expectedCarbs > 0,
        )
        .toList();
    final byMeal = <int, List<Treat>>{};
    for (final event in candidates) {
      final owners = eligible
          .where(
            (item) =>
                !event.createdAt.isBefore(item.savedAt) &&
                !event.createdAt.isAfter(
                  item.savedAt.add(const Duration(minutes: 5)),
                ) &&
                _localDay(event.createdAt) ==
                    _localDay(recordedAtByMeal[item.mealId]!),
          )
          .toList();
      if (owners.length == 1) {
        byMeal.putIfAbsent(owners.single.mealId, () => []).add(event);
      }
    }
    return {
      for (final item in eligible)
        if ((byMeal[item.mealId] ?? const <Treat>[]).fold<int>(
              0,
              (sum, e) => sum + e.carbs,
            ) >=
            item.expectedCarbs)
          item.mealId: byMeal[item.mealId]!,
    };
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
