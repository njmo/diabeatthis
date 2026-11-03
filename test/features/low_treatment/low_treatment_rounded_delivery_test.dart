import 'package:diabeatthis/common/meal/low_treatment_delivery_carbs.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_handoff_pending.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/match_low_treatment_handoffs_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('whole grams use nearest rounding consistently', () {
    expect(lowTreatmentDeliveryCarbs(7.35), 7);
    expect(lowTreatmentDeliveryCarbs(7.5), 8);
    expect(lowTreatmentDeliveryCarbs(12.5), 13);
    expect(() => lowTreatmentDeliveryCarbs(double.nan), throwsArgumentError);
    expect(() => lowTreatmentDeliveryCarbs(0.1), throwsArgumentError);
  });

  final start = DateTime.utc(2026, 11, 3, 14, 13, 54);
  final pending = LowTreatmentHandoffPending(
    mealId: 7,
    savedAt: start,
    expectedCarbs: 7,
    suggestionAt: null,
    matchedTreatAt: null,
    matchedExternalId: null,
  );
  final first = Treat(
    externalId: 'first',
    createdAt: start.add(const Duration(seconds: 13)),
    carbs: 7,
  );
  final second = Treat(
    externalId: 'second',
    createdAt: start.add(const Duration(seconds: 73)),
    carbs: 7,
  );

  Map<int, Treat> match(List<Treat> treatments) =>
      const MatchLowTreatmentHandoffsUseCase()(
        pending: [pending],
        recordedAtByMeal: {7: start},
        treatments: treatments,
        occupiedMealIds: {},
        occupiedTreatTimes: {},
        now: start.add(const Duration(minutes: 2)),
      );

  test('source-rounded intake matches one AAPS receipt', () {
    expect(match([first]), {7: first});
  });

  test('two separate receipts accumulate to the returned amount', () {
    expect(match([first, second])[7]?.carbs, 14);
  });
}
