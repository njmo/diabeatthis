import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  final day = DateTime(2026, 9, 15);
  final time = day.add(const Duration(hours: 12));
  final wizardRecords = TreatmentFactory().parseTreatments([
    {
      '_id': 'meal-carbs',
      'eventType': 'Carb Correction',
      'created_at': time.subtract(const Duration(seconds: 1)).toIso8601String(),
      'carbs': 30,
    },
    {
      '_id': 'wizard',
      'eventType': 'Bolus Wizard',
      'created_at': time.toIso8601String(),
      'glucose': 125,
      'bolusCalculatorResult': {'carbs': 30, 'totalInsulin': 1.5},
    },
    {
      '_id': 'bolus',
      'eventType': 'Meal Bolus',
      'created_at': time.add(const Duration(seconds: 1)).toIso8601String(),
      'insulin': 1.5,
    },
  ]);
  final standalone = Treat(
    externalId: 'standalone',
    createdAt: time.add(const Duration(hours: 1)),
    carbs: 10,
  );
  Future<void> check(List<Treatment> records, List<String?> expected) async {
    final result = await BuildDayContextUseCase(
      now: () => DateTime(2026, 9, 16),
      loadGlucose: (_, _) async => [],
      loadTreatments: (_, _) async => records,
      loadMeals: (_, _) async => emptyMeals,
      loadLowTreatments: (_, _) async => [],
      loadActivities: (_, _) async => [],
    )(date: day);
    expect(result.carbEntries!.map((record) => record.externalId), expected);
    expect(result.wizards, hasLength(1));
    expect(result.boluses!.units, 1.5);
    expect(records, containsAll(wizardRecords.skip(1)));
  }

  test(
    'factory-parsed meal carbohydrates are excluded without losing wizard or insulin',
    () async {
      await check([...wizardRecords, standalone], ['standalone']);
    },
  );

  test('exclusion is independent of history input order', () async {
    await check([standalone, ...wizardRecords.reversed], ['standalone']);
  });

  test(
    'carbohydrates with a different amount remain available for review',
    () async {
      final unmatched = (wizardRecords.first as Treat).copyWith(carbs: 12);
      await check(
        [unmatched, ...wizardRecords.skip(1), standalone],
        ['meal-carbs', 'standalone'],
      );
    },
  );
}
