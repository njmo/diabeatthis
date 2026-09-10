import 'dart:async';

import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_meal_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';

const emptyMeals = DayMealSummary(
  count: 0,
  plannedFallbackCount: 0,
  missingSnapshotCount: 0,
  netCarbs: 0,
  protein: 0,
  fat: 0,
);

void main() {
  test(
    'loads basal history once for day and night and isolates its failure',
    () async {
      final cutoff = DateTime(2026, 9, 10, 0, 10);
      final midnight = DateTime(2026, 9, 10);
      var calls = 0;
      for (final fail in [false, true]) {
        final day = await BuildDayContextUseCase(
          now: () => cutoff,
          loadGlucose: (_, _) async => [],
          loadTreatments: (_, _) async => [],
          loadMeals: (_, _) async => emptyMeals,
          loadLowTreatments: (_, _) async => [],
          loadActivities: (_, _) async => [],
          loadDeviceStatuses: (start, end) async {
            calls++;
            expect(start, DateTime(2026, 9, 9, 21, 50));
            expect(end, cutoff);
            if (fail) throw StateError('offline');
            return [
              testDeviceStatus(
                date: midnight,
                iob: 0,
                cob: 0,
                tick: '',
                bg: 120,
                baseBasalRate: 0.6,
              ).copyWith(basalObservedAt: midnight),
            ];
          },
        )();
        if (fail) {
          expect(day.failedSources, {DayDataSource.deviceStatus});
          expect(day.basal, isNull);
          expect(day.meals, isNotNull);
        } else {
          expect(day.basal!.units, closeTo(0.1, 1e-9));
          expect(day.basal!.coverage, 1);
          expect(day.nightBasal!.coveredDuration, const Duration(minutes: 10));
          expect(day.nightBasal!.coverage, lessThan(1));
        }
      }
      expect(calls, 2);
    },
  );
  test(
    'loads device ages at the shared cutoff and isolates failures',
    () async {
      final now = DateTime(2026, 9, 10, 12);
      final day = await BuildDayContextUseCase(
        now: () => now,
        loadGlucose: (_, _) async => [],
        loadTreatments: (_, _) async => [],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
        loadSensorAge: (cutoff) async {
          expect(cutoff, now);
          return const Duration(days: 7, hours: 3);
        },
        loadPodAge: (cutoff) async => throw StateError('offline'),
      )();
      expect(day.sensorAge, const Duration(days: 7, hours: 3));
      expect(day.podAge, isNull);
      expect(day.failedSources, {DayDataSource.podAge});
      expect(day.meals!.count, 0);
    },
  );

  test(
    'independent sources start concurrently and one failure preserves results',
    () async {
      final gate = Completer<List<Glucose>>();
      final started = <String>[];
      final now = DateTime(2026, 9, 10, 5);
      final builder = BuildDayContextUseCase(
        now: () => now,
        loadGlucose: (start, end) {
          started.add('glucose');
          return gate.future;
        },
        loadTreatments: (start, end) async {
          started.add('treatments');
          throw StateError('offline');
        },
        loadMeals: (start, end) async {
          started.add('meals');
          return emptyMeals;
        },
        loadLowTreatments: (start, end) async {
          started.add('lows');
          return [];
        },
        loadActivities: (start, end) async {
          started.add('activities');
          return [];
        },
      );
      final result = builder();
      expect(started.length, 5);
      gate.complete([]);
      final day = await result;
      expect(day.failedSources, {DayDataSource.treatments});
      expect(day.meals?.count, 0);
      expect(day.boluses, isNull);
      expect(day.nightGlucose!.window.start, DateTime(2026, 9, 9, 22));
      expect(day.nightGlucose!.window.end, now);
    },
  );

  test(
    'night deliveries are a separate view and not added to day total',
    () async {
      final now = DateTime(2026, 9, 10, 12);
      final day = await BuildDayContextUseCase(
        now: () => now,
        loadGlucose: (_, _) async => [],
        loadTreatments: (_, _) async => [
          ManualBolus(
            externalId: '1',
            createdAt: DateTime(2026, 9, 9, 23),
            insulin: 1,
          ),
          ManualBolus(
            externalId: '2',
            createdAt: DateTime(2026, 9, 10, 1),
            insulin: 2,
          ),
          ManualBolus(
            externalId: '3',
            createdAt: DateTime(2026, 9, 10, 8),
            insulin: 3,
          ),
          ManualBolus(
            externalId: '4',
            createdAt: DateTime(2026, 9, 10, 13),
            insulin: 9,
          ),
        ],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      )();
      expect(day.boluses!.units, 5);
      expect(day.nightBoluses!.units, 3);
      expect(day.nightGlucose!.window.end, DateTime(2026, 9, 10, 6));
    },
  );
}
