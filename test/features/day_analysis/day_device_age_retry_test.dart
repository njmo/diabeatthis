import 'dart:async';

import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  final now = DateTime(2026, 9, 11, 12);
  BuildDayContextUseCase build(Future<Duration?> Function(DateTime) sensor) =>
      BuildDayContextUseCase(
        now: () => now,
        loadGlucose: (_, _) async => [],
        loadTreatments: (_, _) async => [],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
        loadSensorAge: sensor,
        loadPodAge: (_) async => const Duration(days: 1),
      );

  test(
    'transient sensor failure recovers in the first day build with the same cutoff',
    () async {
      var calls = 0;
      final day = await build((asOf) async {
        expect(asOf, now);
        if (++calls == 1) throw TimeoutException('startup');
        return const Duration(days: 4);
      })();
      expect(calls, 2);
      expect(day.sensorAge, const Duration(days: 4));
      expect(day.failedSources, isNot(contains(DayDataSource.sensorAge)));
      expect(day.podAge, const Duration(days: 1));
    },
  );

  test(
    'persistent sensor failure is bounded and leaves other sources available',
    () async {
      var calls = 0;
      final day = await build((_) async {
        calls++;
        throw Exception('transport');
      })();
      expect(calls, 2);
      expect(day.failedSources, contains(DayDataSource.sensorAge));
      expect(day.sensorAge, isNull);
      expect(day.podAge, const Duration(days: 1));
    },
  );

  test(
    'empty history and invalid dates are not retried as network failures',
    () async {
      for (final malformed in [false, true]) {
        var calls = 0;
        final day = await build((_) async {
          calls++;
          if (malformed) throw const FormatException('date');
          return null;
        })();
        expect(calls, 1);
        expect(day.sensorAge, isNull);
        expect(day.failedSources.contains(DayDataSource.sensorAge), malformed);
      }
    },
  );
}
