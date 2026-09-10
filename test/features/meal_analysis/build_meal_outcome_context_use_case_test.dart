import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_activity_observation.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_observation_window.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_outcome_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_outcome_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

final mealTime = DateTime(2026, 9, 10, 12);
DateTime at(int minute) => mealTime.add(Duration(minutes: minute));
MealOutcomeContext outcome({
  int elapsed = 90,
  List<Treatment> treatments = const [],
  List<Glucose> glucose = const [],
  List<DeviceStatus> statuses = const [],
  List<RecordedLowTreatment> lows = const [],
  List<MealActivityObservation> activities = const [],
}) => const BuildMealOutcomeContextUseCase()(
  mealTime: mealTime,
  window: const Duration(minutes: 90),
  asOf: at(elapsed),
  builtAt: at(elapsed),
  treatmentHistoryStart: at(-1440),
  glucose: glucose,
  deviceStatuses: statuses,
  treatments: treatments,
  lowTreatments: lows,
  activities: activities,
  subsequentMeals: [],
);

void main() {
  test('an empty observation cannot contain a duration of activity', () {
    expect(
      outcome(
        elapsed: 0,
        activities: [
          MealActivityObservation(
            logId: 1,
            name: 'Running',
            startedAt: at(-20),
            endedAt: null,
          ),
        ],
      ).activities,
      isEmpty,
    );
  });
  test('preserves the existing 90 minute and three hour policy', () {
    expect(MealObservationWindow.forWbtKcal(100), const Duration(minutes: 90));
    expect(MealObservationWindow.forWbtKcal(101), const Duration(hours: 3));
  });
  test(
    'clips observations at now and distinguishes time completion from coverage',
    () {
      final partial = outcome(elapsed: 30);
      expect(partial.observedUntil, at(30));
      expect(partial.isTimeWindowComplete, false);
      final complete = outcome(elapsed: 200);
      expect(complete.observedUntil, at(90));
      expect(complete.isTimeWindowComplete, true);
      expect(complete.basal.coverage, 0);
      expect(complete.glucoseSummary.mean, isNull);
    },
  );
  test(
    'earlier eCarbs count only the schedule allocation overlapping the observed window',
    () {
      final earlier = ExtendedCarb(
        externalId: 'previous',
        createdAt: at(-120),
        carbs: 24,
        duration: 14400000,
      );
      final current = ExtendedCarb(
        externalId: 'current',
        createdAt: at(10),
        carbs: 12,
        duration: 3600000,
      );
      final result = outcome(
        elapsed: 30,
        treatments: [
          earlier,
          earlier,
          current,
          ExtendedCarb(
            externalId: 'ended',
            createdAt: at(-90),
            carbs: 12,
            duration: 3600000,
          ),
          ExtendedCarb(
            externalId: 'future',
            createdAt: at(60),
            carbs: 12,
            duration: 3600000,
          ),
        ],
      );
      expect(result.extendedCarbs.length, 2);
      expect(result.extendedCarbs.first.startedBeforeMeal, true);
      expect(result.extendedCarbs.first.scheduledGrams, 3);
      expect(result.extendedCarbs.last.startedBeforeMeal, false);
      expect(result.extendedCarbs.last.scheduledGrams, 4);
      expect(result.treatments, [current]);
      expect(() => result.extendedCarbs.clear(), throwsUnsupportedError);
    },
  );
  test(
    'counts only post-meal boluses and lows and retains pre-meal CGM baseline',
    () {
      Glucose reading(int minute, GlucoseType type) => Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: at(minute),
        sgv: 120,
        direction: 'Flat',
        type: type,
      );
      final result = outcome(
        elapsed: 30,
        treatments: [
          ManualBolus(externalId: 'before', createdAt: at(-1), insulin: 1),
          ManualBolus(externalId: 'during', createdAt: at(10), insulin: 0.5),
          ManualBolus(externalId: 'after', createdAt: at(60), insulin: 1),
        ],
        glucose: [
          reading(-5, GlucoseType.cgm),
          reading(5, GlucoseType.cgm),
          reading(60, GlucoseType.cgm),
          reading(10, GlucoseType.finger),
        ],
        lows: [
          for (final minute in [-1, 15, 60])
            RecordedLowTreatment(
              mealId: minute,
              eatenAt: at(minute),
              netCarbsGrams: 5,
            ),
        ],
      );
      expect(result.boluses.units, 0.5);
      expect(result.glucoseSummary.window.baseline!.date, at(-5));
      expect(result.glucose.length, 2);
      expect(result.lowTreatments.single.eatenAt, at(15));
    },
  );
  test('preserves actual activity start and clips only observed duration', () {
    final result = outcome(
      elapsed: 30,
      activities: [
        MealActivityObservation(
          logId: 1,
          name: 'Running',
          startedAt: at(-20),
          endedAt: at(60),
        ),
        MealActivityObservation(
          logId: 2,
          name: 'Earlier',
          startedAt: at(-30),
          endedAt: at(0),
        ),
      ],
    );
    expect(result.activities.length, 1);
    expect(result.activities.single.startedAt, at(-20));
    expect(
      result.activities.single.observedDuration(mealTime, at(30)),
      const Duration(minutes: 30),
    );
    expect(result.activities.single.endedAt, isNull);
  });
}
