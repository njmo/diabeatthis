import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/domain/model/stress_event.dart';
import 'package:diabeatthis/core/domain/model/stress_event_treatment.dart';
import 'package:diabeatthis/core/domain/model/stress_level.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/before_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_activity_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';

final cutoff = DateTime(2026, 9, 10, 12);
final macros = MealMacroSummary(
  carbsGrams: 20,
  fatGrams: 10,
  proteinGrams: 12,
  fiberGrams: 2,
  totalGrams: 100,
);
Glucose reading(int minutes, {GlucoseType type = GlucoseType.cgm}) => Glucose(
  externalId: null,
  source: GlucoseSource.cloud,
  date: cutoff.add(Duration(minutes: minutes)),
  sgv: 120,
  direction: 'Flat',
  type: type,
);
BuildBeforeMealContextUseCase builder({
  Future<List<Glucose>> Function(DateTime, DateTime)? glucose,
  List<DeviceStatus>? statuses,
  List<Treatment> treatments = const [],
  List<MealActivityContext> activities = const [],
  List<RecordedMealContext> meals = const [],
  Duration timeout = const Duration(seconds: 15),
}) => BuildBeforeMealContextUseCase(
  loadGlucose: glucose ?? (_, _) async => [],
  loadDeviceStatuses: (_, _) async =>
      statuses ??
      [
        testDeviceStatus(
          date: cutoff,
          iob: 0.8,
          basalIob: -0.2,
          cob: 3,
          tick: '+1',
          bg: 120,
        ),
      ],
  loadTreatments: (_, _) async => treatments,
  loadMeals: (_, _, _) async => meals,
  loadLowTreatments: (_, _) async => [],
  loadActivities: (_, _, _) async => activities,
  loadPodAge: (_) async => const Duration(days: 2),
  now: () => cutoff,
  timeout: timeout,
);
void main() {
  test(
    'retains a stress interval that starts before the history lookback',
    () async {
      final stress = StressEventTreatment(
        StressEvent(
          occurredAt: cutoff.subtract(const Duration(hours: 25)),
          endedAt: cutoff.subtract(const Duration(hours: 1)),
          source: 'manual',
          stressLevel: StressLevel.high,
        ),
      );
      final context = await builder(treatments: [stress])(
        asOf: cutoff,
        macros: macros,
      );
      expect(context.treatments, [stress]);
    },
  );
  test(
    'future calculation timestamps are removed from exposed AAPS evidence',
    () async {
      final future = cutoff.add(const Duration(minutes: 1));
      final status =
          testDeviceStatus(
            date: cutoff,
            iob: 1,
            cob: 2,
            tick: '+1',
            bg: 120,
          ).copyWith(
            insulinActivityAt: future,
            insulinActivity: 0.02,
            aapsPredictionsJson: jsonEncode({
              'timestamp': future.toIso8601String(),
              'predBGs': {
                'IOB': [120, 130],
              },
            }),
          );
      final context = await builder(statuses: [status])(
        asOf: cutoff,
        macros: macros,
      );
      expect(context.predictions, isNull);
      expect(context.latestDeviceStatus!.aapsPredictionsJson, isNull);
      expect(context.latestDeviceStatus!.hasInsulinActivity, false);
    },
  );
  test(
    'history sources start before a blocked glucose request completes',
    () async {
      final gate = Completer<List<Glucose>>();
      final started = <String>[];
      final base = builder();
      final useCase = BuildBeforeMealContextUseCase(
        loadGlucose: (_, _) {
          started.add('glucose');
          return gate.future;
        },
        loadDeviceStatuses: (_, _) async {
          started.add('status');
          return [];
        },
        loadTreatments: (_, _) async {
          started.add('treatments');
          return [];
        },
        loadMeals: base.loadMeals,
        loadLowTreatments: base.loadLowTreatments,
        loadActivities: base.loadActivities,
        loadPodAge: base.loadPodAge,
        now: base.now,
      );
      final result = useCase(asOf: cutoff, macros: macros);
      expect(started, ['glucose', 'status', 'treatments']);
      gate.complete([]);
      expect((await result).failedSources, isEmpty);
    },
  );
  test(
    'normalizes CGM, excludes future readings and spot checks, retains negative basal IOB',
    () async {
      final context = await builder(
        glucose: (_, _) async => [
          reading(5),
          reading(-5),
          reading(-5),
          reading(0, type: GlucoseType.finger),
        ],
      )(asOf: cutoff, macros: macros);
      expect(context.glucose!.length, 1);
      expect(
        context.latestCgm!.date,
        cutoff.subtract(const Duration(minutes: 5)),
      );
      expect(context.hasFreshCgm, true);
      expect(context.latestDeviceStatus!.basalIob, -0.2);
      expect(context.podAge, const Duration(days: 2));
      expect(() => context.glucose!.clear(), throwsUnsupportedError);
    },
  );
  test('exactly ten minute CGM is stale, not missing', () async {
    final context = await builder(glucose: (_, _) async => [reading(-10)])(
      asOf: cutoff,
      macros: macros,
    );
    expect(context.latestCgm, isNotNull);
    expect(context.hasFreshCgm, false);
  });
  test('timeout isolates failure while independent sources complete', () async {
    final pending = Completer<List<Glucose>>();
    final context = await builder(
      glucose: (_, _) => pending.future,
      timeout: const Duration(milliseconds: 10),
    )(asOf: cutoff, macros: macros);
    expect(context.failedSources, {BeforeMealSource.glucose});
    expect(context.glucoseSummary, isNull);
    expect(context.priorMeals, isEmpty);
    expect(context.latestDeviceStatus, isNotNull);
    pending.complete([]);
  });
  test(
    'eCarbs uses milliseconds and exposes schedule remainder without future events',
    () async {
      final active = ExtendedCarb(
        externalId: 'active',
        createdAt: cutoff.subtract(const Duration(hours: 1)),
        carbs: 20,
        duration: const Duration(hours: 2).inMilliseconds,
      );
      final context = await builder(
        treatments: [
          active,
          active,
          ExtendedCarb(
            externalId: 'future',
            createdAt: cutoff.add(const Duration(hours: 1)),
            carbs: 20,
            duration: 7200000,
          ),
          ExtendedCarb(
            externalId: 'invalid',
            createdAt: cutoff,
            carbs: 20,
            duration: 0,
          ),
        ],
      )(asOf: cutoff, macros: macros);
      expect(context.extendedCarbPlans!.length, 1);
      expect(context.extendedCarbPlans!.single.scheduledBeforeCutoffGrams, 10);
      expect(context.extendedCarbPlans!.single.scheduledAfterCutoffGrams, 10);
    },
  );
  test(
    'only known upcoming activities are included and future actual ends are hidden',
    () async {
      MealActivityContext activity(int id, int begins, int created) =>
          MealActivityContext(
            logId: id,
            name: 'Training',
            startedAt: cutoff.add(Duration(minutes: begins)),
            endedAt: cutoff.add(const Duration(hours: 2)),
            recordedAt: cutoff.add(Duration(minutes: created)),
            plannedDurationMinutes: 60,
            percentagePre: 70,
            percentagePost: 80,
          );
      final context = await builder(
        activities: [
          activity(1, -30, -60),
          activity(2, 30, -60),
          activity(3, 60, 5),
        ],
      )(asOf: cutoff, macros: macros);
      expect(context.activities!.map((a) => a.logId), [1, 2]);
      expect(context.activities!.every((a) => a.endedAt == null), true);
    },
  );
  test('future context cannot be mistaken for observed history', () async {
    await expectLater(
      builder()(asOf: cutoff.add(const Duration(minutes: 1)), macros: macros),
      throwsArgumentError,
    );
  });
}
