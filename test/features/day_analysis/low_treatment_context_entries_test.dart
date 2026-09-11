import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  test(
    'day review includes standalone Treat entries and excludes every extended carb',
    () async {
      final day = DateTime(2026, 9, 10);
      final context = await BuildDayContextUseCase(
        now: () => day.add(const Duration(days: 1)),
        loadGlucose: (_, _) async => [],
        loadTreatments: (_, _) async => [
          Treat(externalId: 'standalone', createdAt: day, carbs: 10),
          Treat(
            externalId: 'invalid',
            createdAt: day,
            carbs: 10,
            isValid: false,
          ),
          Treat(
            externalId: 'night',
            createdAt: day.subtract(const Duration(hours: 1)),
            carbs: 10,
          ),
          ExtendedCarb(
            externalId: 'zero',
            createdAt: day,
            carbs: 10,
            duration: 0,
          ),
          ExtendedCarb(
            externalId: 'extended',
            createdAt: day,
            carbs: 10,
            duration: 3600000,
          ),
        ],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      )(date: day);
      expect(context.carbEntries!.map((event) => event.externalId), [
        'standalone',
      ]);
    },
  );
}
