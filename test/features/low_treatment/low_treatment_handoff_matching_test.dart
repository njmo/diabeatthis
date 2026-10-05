import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_handoff_pending.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/match_low_treatment_handoffs_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 28, 12);
  final pending = LowTreatmentHandoffPending(
    mealId: 1,
    savedAt: start,
    expectedCarbs: 10,
    suggestionAt: null,
    matchedTreatAt: null,
    matchedExternalId: null,
  );
  Map<int, Treat> match(List<Treat> events, {Set<int> occupied = const {}}) =>
      const MatchLowTreatmentHandoffsUseCase()(
        pending: [pending],
        recordedAtByMeal: {1: start},
        treatments: events,
        occupiedMealIds: {},
        occupiedTreatTimes: occupied,
        now: start.add(const Duration(minutes: 10)),
      );
  Treat event(int seconds, {int grams = 10, String? id = 'remote'}) => Treat(
    externalId: id,
    createdAt: start.add(Duration(seconds: seconds)),
    carbs: grams,
  );

  test(
    'requires exact amount and a timestamp inside the five-minute window',
    () {
      expect(match([event(-1)]), isEmpty);
      expect(match([event(301)]), isEmpty);
      expect(match([event(60, grams: 9)]), isEmpty);
      expect(match([event(300)]).keys, [1]);
    },
  );
  test(
    'merges local and remote copies, but refuses conflicting identities',
    () {
      expect(match([event(60, id: null), event(60)])[1]?.externalId, 'remote');
      expect(match([event(60, id: 'one'), event(60, id: 'two')]), isEmpty);
      expect(match([event(60), event(60, grams: 11)]), isEmpty);
    },
  );
  test(
    'does not choose between two valid events or replace a manual decision',
    () {
      expect(match([event(60), event(120)]), isEmpty);
      expect(
        match(
          [event(60)],
          occupied: {event(60).createdAt.millisecondsSinceEpoch},
        ),
        isEmpty,
      );
    },
  );
  test(
    'does not create a cross-day relation hidden by day review boundaries',
    () {
      final midnight = DateTime(2026, 9, 29);
      final saved = midnight.subtract(const Duration(minutes: 1));
      expect(
        const MatchLowTreatmentHandoffsUseCase()(
          pending: [
            LowTreatmentHandoffPending(
              mealId: 1,
              savedAt: saved,
              expectedCarbs: 10,
              suggestionAt: null,
              matchedTreatAt: null,
              matchedExternalId: null,
            ),
          ],
          recordedAtByMeal: {1: saved},
          treatments: [
            Treat(externalId: 'remote', createdAt: midnight, carbs: 10),
          ],
          occupiedMealIds: {},
          occupiedTreatTimes: {},
          now: midnight,
        ),
        isEmpty,
      );
    },
  );
}
