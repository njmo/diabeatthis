import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/history/glucose_window_summary.dart';
import 'package:diabeatthis/common/history/nearest_cgm_reading.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_outcome_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 9, 20, 0, 24);
  Glucose sample(
    int milliseconds, {
    int value = 132,
    GlucoseType type = GlucoseType.cgm,
  }) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: start.add(Duration(milliseconds: milliseconds)),
    sgv: value,
    type: type,
    direction: 'Flat',
  );
  test(
    'reproduces the logged 409ms offset without modifying the timestamp',
    () {
      final near = sample(409);
      final readings = [sample(-300278, value: 130), near];
      expect(nearestCgmReading(readings, start), same(near));
      expect(
        nearestCgmReading(readings, start)!.date,
        start.add(const Duration(milliseconds: 409)),
      );
    },
  );
  test(
    'chooses closest in either direction and earlier on an unordered tie',
    () {
      final before = sample(-60000);
      final after = sample(60000);
      expect(nearestCgmReading([after, before], start), same(before));
      expect(
        nearestCgmReading([before, sample(20000)], start)!.date,
        start.add(const Duration(seconds: 20)),
      );
    },
  );
  test(
    'accepts exactly five minutes and rejects distant or non-CGM samples',
    () {
      expect(nearestCgmReading([sample(300000)], start), isNotNull);
      expect(nearestCgmReading([sample(-300000)], start), isNotNull);
      expect(
        nearestCgmReading([
          sample(300001),
          sample(-300001),
          sample(0, type: GlucoseType.finger),
          sample(0, value: 0),
        ], start),
        isNull,
      );
    },
  );
  test(
    'meal outcome uses the retrospective policy for the real logged boundary',
    () {
      final reading = sample(409);
      final data = const BuildMealOutcomeContextUseCase()(
        mealTime: start,
        window: const Duration(minutes: 90),
        asOf: start.add(const Duration(hours: 2)),
        builtAt: start.add(const Duration(hours: 2)),
        treatmentHistoryStart: start.subtract(const Duration(days: 1)),
        glucose: [sample(-300278), reading],
        deviceStatuses: [],
        treatments: [],
        lowTreatments: [],
        activities: [],
        subsequentMeals: [],
      );
      expect(data.glucoseSummary.window.baseline, reading);
    },
  );
  test(
    'live default stays causal and retrospective baseline does not fill gaps',
    () {
      final readings = [sample(409), sample(300409, value: 140)];
      final end = start.add(const Duration(minutes: 15));
      final live = GlucosePeriodSummary.calculate(readings, start, end);
      final history = GlucosePeriodSummary.calculate(
        readings,
        start,
        end,
        baselinePolicy: GlucoseBaselinePolicy.nearest,
      );
      expect(live.window.baseline, isNull);
      expect(history.window.baseline, readings.first);
      expect(history.mean, live.mean);
      expect(history.window.missing, live.window.missing);
      expect(history.window.inRange, live.window.inRange);
      expect(
        GlucoseWindowSummary(
          readings: readings,
          start: start,
          end: start,
          baselinePolicy: GlucoseBaselinePolicy.nearest,
        ).baseline,
        isNull,
      );
    },
  );
}
