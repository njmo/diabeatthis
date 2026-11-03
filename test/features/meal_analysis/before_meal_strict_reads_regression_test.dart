import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/before_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_activity_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/scripted_read.dart';
import 'build_before_meal_context_use_case_test.dart' show cutoff, macros;

void main() {
  for (final failure in [null, ...BeforeMealSource.values]) {
    test(
      'each historical read has an exact cutoff; isolated failure=$failure',
      () async {
        T response<T>(BeforeMealSource source, T value) {
          if (source == failure) throw StateError('Scripted $source failure');
          return value;
        }

        final glucose = ScriptedRead<List<Glucose>>('glucose', [
          (
            arguments: [cutoff.subtract(const Duration(minutes: 50)), cutoff],
            respond: () => response(BeforeMealSource.glucose, <Glucose>[
              Glucose(
                externalId: 'at-cutoff',
                source: GlucoseSource.cloud,
                date: cutoff,
                sgv: 123,
                direction: 'Flat',
              ),
              Glucose(
                externalId: 'future',
                source: GlucoseSource.cloud,
                date: cutoff.add(const Duration(minutes: 1)),
                sgv: 999,
                direction: 'Flat',
              ),
            ]),
          ),
        ]);
        // Device history includes a basal carry-in before the six-hour window.
        final statuses = ScriptedRead<List<DeviceStatus>>('statuses', [
          (
            arguments: [
              cutoff.subtract(const Duration(hours: 6, minutes: 10)),
              cutoff,
            ],
            respond: () =>
                response(BeforeMealSource.deviceStatus, <DeviceStatus>[]),
          ),
        ]);
        final treatments = ScriptedRead<List<Treatment>>('treatments', [
          (
            arguments: [cutoff.subtract(const Duration(hours: 24)), cutoff],
            respond: () => response(BeforeMealSource.treatments, <Treatment>[]),
          ),
        ]);
        final meals = ScriptedRead<List<RecordedMealContext>>('meals', [
          (
            arguments: [cutoff.subtract(const Duration(hours: 24)), cutoff, 77],
            respond: () =>
                response(BeforeMealSource.meals, <RecordedMealContext>[]),
          ),
        ]);
        final lows = ScriptedRead<List<RecordedLowTreatment>>('lows', [
          (
            arguments: [cutoff.subtract(const Duration(hours: 24)), cutoff],
            respond: () => response(
              BeforeMealSource.lowTreatments,
              <RecordedLowTreatment>[],
            ),
          ),
        ]);
        final activities = ScriptedRead<List<MealActivityContext>>(
          'activities',
          [
            (
              arguments: [
                cutoff.subtract(const Duration(hours: 24)),
                cutoff.add(const Duration(hours: 3)),
                cutoff,
              ],
              respond: () => response(
                BeforeMealSource.activities,
                <MealActivityContext>[],
              ),
            ),
          ],
        );
        final pod = ScriptedRead<Duration?>('pod', [
          (
            arguments: [cutoff],
            respond: () =>
                response(BeforeMealSource.podAge, const Duration(hours: 37)),
          ),
        ]);
        final result = await BuildBeforeMealContextUseCase(
          loadGlucose: (a, b) => glucose([a, b]),
          loadDeviceStatuses: (a, b) => statuses([a, b]),
          loadTreatments: (a, b) => treatments([a, b]),
          loadMeals: (a, b, id) => meals([a, b, id]),
          loadLowTreatments: (a, b) => lows([a, b]),
          loadActivities: (a, b, c) => activities([a, b, c]),
          loadPodAge: (a) => pod([a]),
          now: () => cutoff,
        )(asOf: cutoff, mealId: 77, macros: macros);
        glucose.verifyComplete();
        statuses.verifyComplete();
        treatments.verifyComplete();
        meals.verifyComplete();
        lows.verifyComplete();
        activities.verifyComplete();
        pod.verifyComplete();
        expect(result.failedSources, failure == null ? isEmpty : {failure});
        expect(result.macros!.netCarbsGrams, 20);
        expect(
          result.latestCgm?.sgv,
          failure == BeforeMealSource.glucose ? null : 123,
        );
        expect(
          result.podAge,
          failure == BeforeMealSource.podAge ? null : const Duration(hours: 37),
        );
        expect(
          result.priorMeals,
          failure == BeforeMealSource.meals ? isNull : isEmpty,
        );
        expect(
          result.lowTreatments,
          failure == BeforeMealSource.lowTreatments ? isNull : isEmpty,
        );
        expect(
          result.activities,
          failure == BeforeMealSource.activities ? isNull : isEmpty,
        );
      },
    );
  }
}
