import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/analyze_meal_glucose_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mealTime = DateTime(2026, 9, 9, 20);
  Glucose sample(
    int minutes,
    int value, {
    GlucoseType type = GlucoseType.cgm,
  }) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: mealTime.add(Duration(minutes: minutes)),
    sgv: value,
    direction: 'Flat',
    type: type,
  );
  test(
    'glucose-only analysis requests a bounded window and preserves weighted statistics',
    () async {
      var calls = 0;
      final useCase = AnalyzeMealGlucoseUseCase(
        now: () => mealTime.add(const Duration(days: 1)),
        loadGlucose: (start, end) async {
          calls++;
          expect(start, mealTime.subtract(const Duration(minutes: 5)));
          expect(end, mealTime.add(const Duration(minutes: 10)));
          return [
            sample(0, 100),
            sample(5, 120),
            sample(10, 140),
            sample(20, 300),
            sample(1, 500, type: GlucoseType.finger),
          ];
        },
      );
      final result = await useCase(
        mealTime: mealTime,
        window: const Duration(minutes: 90),
        asOf: mealTime.add(const Duration(minutes: 10)),
      );
      expect(calls, 1);
      expect(result.glucoseSummary.mean, 110);
      expect(result.glucoseSummary.window.peak!.sgv, 140);
      expect(result.isTimeWindowComplete, isFalse);
    },
  );
  test(
    'future cutoff is bounded by current time; invalid cutoff does not fetch',
    () async {
      var calls = 0;
      final useCase = AnalyzeMealGlucoseUseCase(
        now: () => mealTime.add(const Duration(minutes: 5)),
        loadGlucose: (start, end) async {
          calls++;
          expect(end, mealTime.add(const Duration(minutes: 5)));
          return [];
        },
      );
      await useCase(
        mealTime: mealTime,
        window: const Duration(minutes: 90),
        asOf: mealTime.add(const Duration(days: 1)),
      );
      await expectLater(
        useCase(
          mealTime: mealTime,
          window: const Duration(minutes: 90),
          asOf: mealTime.subtract(const Duration(minutes: 1)),
        ),
        throwsArgumentError,
      );
      expect(calls, 1);
    },
  );
}
