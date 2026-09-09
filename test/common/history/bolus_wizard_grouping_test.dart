import 'package:diabeatthis/common/history/bolus_wizard_grouping.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/correction_bolus.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final time = DateTime.utc(2026, 5, 24, 7, 41, 32);
  final wizard =
      TreatmentFactory().parseTreatments([
            {
              'eventType': 'Bolus Wizard',
              'created_at': time.toIso8601String(),
              'date': time.millisecondsSinceEpoch,
              'glucose': 125,
              'bolusCalculatorResult': {'carbs': 23, 'totalInsulin': 1.4},
            },
          ]).single
          as BolusWizard;
  final insulin = ManualBolus(
    externalId: 'delivery',
    createdAt: time.add(const Duration(seconds: 3)),
    insulin: 1.4,
  );
  final carbs = Treat(
    externalId: 'carbs',
    createdAt: time.subtract(const Duration(seconds: 1)),
    carbs: 23,
  );

  test('groups chronological neighbours regardless of input order', () {
    final records = [insulin, wizard, carbs];
    for (final input in [records, records.reversed]) {
      expect(BolusWizardGrouping(input).relatedRecords, {insulin, carbs});
    }
  });

  test('groups adjacent delivery even after a delay exceeding ten seconds', () {
    final delayed = insulin.copyWith(
      createdAt: time.add(const Duration(minutes: 2)),
    );
    expect(BolusWizardGrouping([carbs, wizard, delayed]).relatedRecords, {
      carbs,
      delayed,
    });
  });

  test('does not search past an intervening SMB or another treatment', () {
    final smb = CorrectionBolus(
      externalId: 'smb',
      createdAt: time.add(const Duration(seconds: 1)),
      insulin: 0.1,
    );
    expect(BolusWizardGrouping([carbs, wizard, smb, insulin]).relatedRecords, {
      carbs,
    });
    final laterCarbs = carbs.copyWith(
      externalId: 'extra',
      createdAt: time.add(const Duration(seconds: 1)),
    );
    expect(
      BolusWizardGrouping([carbs, wizard, laterCarbs, insulin]).relatedRecords,
      {carbs},
    );
  });

  test('keeps differing amounts and invalid records separate', () {
    for (final dose in [0.2, double.nan]) {
      expect(
        BolusWizardGrouping([
          carbs.copyWith(carbs: 7),
          wizard,
          insulin.copyWith(insulin: dose),
        ]).relatedRecords,
        isEmpty,
      );
    }
    expect(
      BolusWizardGrouping([
        carbs,
        wizard.copyWith(isValid: false),
        insulin,
      ]).relatedRecords,
      isEmpty,
    );
    expect(
      BolusWizardGrouping([
        carbs.copyWith(isValid: false),
        wizard,
        insulin.copyWith(isValid: false),
      ]).relatedRecords,
      isEmpty,
    );
  });

  test('does not group insulin before or carbs after the calculator', () {
    expect(
      BolusWizardGrouping([
        insulin.copyWith(createdAt: time.subtract(const Duration(seconds: 1))),
        wizard,
        carbs.copyWith(createdAt: time.add(const Duration(seconds: 1))),
      ]).relatedRecords,
      isEmpty,
    );
  });

  test('handles missing neighbours and calculator with zero carbs', () {
    expect(BolusWizardGrouping([wizard]).relatedRecords, isEmpty);
    final zeroCarbsWizard = wizard.copyWith(
      calculatorResult: wizard.calculatorResult!.copyWith(carbs: 0),
    );
    expect(BolusWizardGrouping([zeroCarbsWizard, insulin]).relatedRecords, {
      insulin,
    });
  });

  test('does not group a second delivery or reuse previous meal records', () {
    final secondInsulin = insulin.copyWith(
      externalId: 'second',
      createdAt: time.add(const Duration(seconds: 4)),
    );
    final nextWizard = wizard.copyWith(
      createdAt: time.add(const Duration(minutes: 1)),
    );
    expect(
      BolusWizardGrouping([
        carbs,
        wizard,
        insulin,
        secondInsulin,
        nextWizard,
      ]).relatedRecords,
      {carbs, insulin},
    );
  });
}
