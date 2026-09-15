import 'package:diabeatthis/common/history/bolus_wizard_grouping.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/day_analysis/build_day_context_use_case_test.dart'
    show emptyMeals;

void main() {
  final time = DateTime(2026, 9, 15, 12);
  final wizard =
      TreatmentFactory().parseTreatments([
            {
              'eventType': 'Bolus Wizard',
              'created_at': time.toIso8601String(),
              'glucose': 125,
              'bolusCalculatorResult': {'carbs': 20, 'totalInsulin': 1.0},
            },
          ]).single
          as BolusWizard;
  final carbs = Treat(externalId: 'carbs', createdAt: time, carbs: 20);
  final insulin = ManualBolus(externalId: 'bolus', createdAt: time, insulin: 1);

  test('keeps independent intake two hours before a matching calculator', () {
    final earlier = carbs.copyWith(
      createdAt: time.subtract(const Duration(hours: 2)),
    );
    expect(BolusWizardGrouping([earlier, wizard]).relatedRecords, isEmpty);
  });

  test('only groups carbs within the calculator submission window', () {
    for (final milliseconds in [0, 9999, 10000, 10001]) {
      final earlier = carbs.copyWith(
        createdAt: time.subtract(Duration(milliseconds: milliseconds)),
      );
      expect(
        BolusWizardGrouping([earlier, wizard]).isRelated(earlier),
        milliseconds <= 10000,
      );
    }
  });

  test('groups equal-time submission in every source order', () {
    for (final input in permutations([carbs, wizard, insulin])) {
      expect(BolusWizardGrouping(input).relatedRecords, {carbs, insulin});
    }
  });

  test(
    'does not resolve competing equal-time carbs or calculators by input order',
    () {
      for (final records in [
        [carbs, carbs.copyWith(externalId: 'second'), wizard],
        [carbs, wizard, wizard.copyWith()],
      ]) {
        for (final input in permutations(records)) {
          expect(BolusWizardGrouping(input).relatedRecords, isEmpty);
        }
      }
    },
  );

  test('ambiguous timestamp cannot claim a neighbouring intake', () {
    final earlier = carbs.copyWith(
      createdAt: time.subtract(const Duration(seconds: 1)),
    );
    expect(
      BolusWizardGrouping([earlier, wizard, wizard.copyWith()]).relatedRecords,
      isEmpty,
    );
  });

  test(
    'day review keeps distant carbs and excludes one equal-time submission',
    () async {
      final earlier = carbs.copyWith(
        externalId: 'independent',
        createdAt: time.subtract(const Duration(hours: 2)),
      );
      for (final input in permutations([carbs, wizard, insulin])) {
        final result = await BuildDayContextUseCase(
          now: () => DateTime(2026, 9, 16),
          loadGlucose: (_, _) async => [],
          loadTreatments: (_, _) async => [earlier, ...input],
          loadMeals: (_, _) async => emptyMeals,
          loadLowTreatments: (_, _) async => [],
          loadActivities: (_, _) async => [],
        )(date: time);
        expect(result.carbEntries, [earlier]);
        expect(result.wizards, [wizard]);
        expect(result.boluses!.units, 1);
      }
    },
  );
}

Iterable<List<Treatment>> permutations(List<Treatment> records) sync* {
  if (records.isEmpty) {
    yield [];
    return;
  }
  for (var index = 0; index < records.length; index++) {
    final rest = [...records]..removeAt(index);
    for (final tail in permutations(rest)) {
      yield [records[index], ...tail];
    }
  }
}
