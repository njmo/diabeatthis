import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_window.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  test(
    'past day has its own night, excludes next midnight and shares age cutoff',
    () async {
      final now = DateTime(2026, 9, 11, 12);
      final date = DateTime(2026, 9, 9, 20);
      final midnight = DateTime(2026, 9, 10);
      final queryEnd = midnight.subtract(const Duration(microseconds: 1));
      final ranges = <String>[];
      final day = await BuildDayContextUseCase(
        now: () => now,
        loadGlucose: (start, end) async {
          expect(start, DateTime(2026, 9, 8, 21, 55));
          expect(end, queryEnd);
          return [
            for (final entry in [
              (DateTime(2026, 9, 9, 23, 55), 100),
              (midnight, 300),
            ])
              Glucose(
                externalId: null,
                source: GlucoseSource.cloud,
                date: entry.$1,
                sgv: entry.$2,
                direction: '',
              ),
          ];
        },
        loadTreatments: (start, end) async {
          expect(start, DateTime(2026, 9, 8, 22));
          expect(end, queryEnd);
          return [
            ManualBolus(
              externalId: null,
              createdAt: DateTime(2026, 9, 8, 23),
              insulin: 1,
            ),
            ManualBolus(
              externalId: null,
              createdAt: DateTime(2026, 9, 9, 1),
              insulin: 2,
            ),
            ManualBolus(
              externalId: null,
              createdAt: DateTime(2026, 9, 9, 23),
              insulin: 3,
            ),
            ManualBolus(externalId: null, createdAt: midnight, insulin: 9),
          ];
        },
        loadMeals: (start, end) async {
          ranges.add('meals');
          expect(start, DateTime(2026, 9, 9));
          expect(end, queryEnd);
          return emptyMeals;
        },
        loadLowTreatments: (start, end) async {
          ranges.add('lows');
          expect(start, DateTime(2026, 9, 9));
          expect(end, queryEnd);
          return [];
        },
        loadActivities: (start, end) async {
          ranges.add('activities');
          expect(start, DateTime(2026, 9, 9));
          expect(end, midnight);
          return [];
        },
        loadSensorAge: (cutoff) async {
          expect(cutoff, midnight);
          return const Duration(days: 5);
        },
        loadPodAge: (cutoff) async {
          expect(cutoff, midnight);
          return const Duration(days: 2);
        },
      )(date: date);
      expect(ranges, ['meals', 'lows', 'activities']);
      expect(day.isComplete, isTrue);
      expect(day.asOf, midnight);
      expect(day.builtAt, now);
      expect(day.glucose!.window.peak!.sgv, 100);
      expect(day.glucose!.window.observed, const Duration(minutes: 5));
      expect(day.boluses!.units, 5);
      expect(day.nightBoluses!.units, 3);
      expect(day.nightGlucose!.window.start, DateTime(2026, 9, 8, 22));
      expect(day.nightGlucose!.window.end, DateTime(2026, 9, 9, 6));
    },
  );

  test(
    'today remains partial and future calendar days fail before I/O',
    () async {
      final now = DateTime(2026, 9, 11, 3);
      var calls = 0;
      final builder = BuildDayContextUseCase(
        now: () => now,
        loadGlucose: (_, _) async {
          calls++;
          return [];
        },
        loadTreatments: (_, _) async => [],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      );
      await expectLater(
        builder(date: DateTime(2026, 9, 12)),
        throwsArgumentError,
      );
      expect(calls, 0);
      final day = await builder(date: DateTime(2026, 9, 11, 23));
      expect(day.isComplete, isFalse);
      expect(day.asOf, now);
      expect(day.nightGlucose!.window.end, now);
    },
  );

  test(
    'calendar days preserve local DST boundaries instead of adding 24 hours',
    () {
      for (final date in [DateTime(2026, 3, 29), DateTime(2026, 10, 25)]) {
        final next = DateTime(date.year, date.month, date.day + 1);
        final window = DayAnalysisWindow(
          now: DateTime(2026, 12, 1),
          date: date,
        );
        expect(window.start, date);
        expect(window.end, next);
        expect(window.end.hour, 0);
        final offsetChange = next.timeZoneOffset - date.timeZoneOffset;
        expect(
          window.end.difference(window.start),
          const Duration(days: 1) - offsetChange,
        );
        expect(window.nightEnd, DateTime(date.year, date.month, date.day, 6));
      }
    },
  );
}
