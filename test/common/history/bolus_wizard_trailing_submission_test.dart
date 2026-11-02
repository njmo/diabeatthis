import 'package:diabeatthis/common/history/bolus_wizard_grouping.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/correction_bolus.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fixture in [
    trailingSubmission(),
    trailingSubmission(
      carbs: 13,
      recommendation: 24.2,
      deliveryDelayMilliseconds: 798,
      carbDelayMilliseconds: 798,
    ),
  ]) {
    test(
      'groups trailing ${fixture.carbs.carbs} g across every source order and preserves adjusted delivery',
      () {
        for (final input in submissionOrders([
          fixture.wizard,
          fixture.insulin,
          fixture.carbs,
        ])) {
          expect(BolusWizardGrouping(input).relatedRecords, {fixture.carbs});
          expect(input.whereType<ManualBolus>().single.insulin, 3);
        }
      },
    );
  }

  test('groups an equal-time trailing delivery when its amount matches', () {
    final fixture = trailingSubmission(
      recommendation: 3,
      carbDelayMilliseconds: 830,
    );
    for (final input in submissionOrders([
      fixture.wizard,
      fixture.insulin,
      fixture.carbs,
    ])) {
      expect(BolusWizardGrouping(input).relatedRecords, {
        fixture.insulin,
        fixture.carbs,
      });
    }
  });

  test('does not claim trailing carbs without a complete delivery pair', () {
    final fixture = trailingSubmission();
    for (final input in [
      [fixture.wizard, fixture.carbs],
      [fixture.wizard, fixture.insulin],
      [fixture.insulin, fixture.carbs],
    ]) {
      expect(BolusWizardGrouping(input).relatedRecords, isEmpty);
    }
  });

  test('keeps differing carbohydrate amounts independent', () {
    final fixture = trailingSubmission();
    expect(
      BolusWizardGrouping([
        fixture.wizard,
        fixture.insulin,
        fixture.carbs.copyWith(carbs: 7),
      ]).relatedRecords,
      isEmpty,
    );
  });

  test('does not search past an unrelated intervening treatment', () {
    final fixture = trailingSubmission();
    final correction = CorrectionBolus(
      externalId: 'intervening',
      createdAt: fixture.wizard.createdAt.add(const Duration(milliseconds: 1)),
      insulin: 0.1,
    );
    expect(
      BolusWizardGrouping([
        fixture.wizard,
        correction,
        fixture.insulin,
        fixture.carbs,
      ]).relatedRecords,
      isEmpty,
    );
  });

  test('requires the entire trailing pair within the submission window', () {
    for (final milliseconds in [10000, 10001]) {
      final fixture = trailingSubmission(carbDelayMilliseconds: milliseconds);
      expect(
        BolusWizardGrouping([
          fixture.wizard,
          fixture.insulin,
          fixture.carbs,
        ]).isRelated(fixture.carbs),
        milliseconds <= 10000,
      );
    }
  });

  test('does not reinterpret later carbs followed by a separate delivery', () {
    final fixture = trailingSubmission(
      deliveryDelayMilliseconds: 831,
      carbDelayMilliseconds: 830,
    );
    expect(
      BolusWizardGrouping([
        fixture.wizard,
        fixture.carbs,
        fixture.insulin,
      ]).relatedRecords,
      isEmpty,
    );
  });

  test(
    'keeps ambiguous trailing records independent in every source order',
    () {
      final fixture = trailingSubmission(carbDelayMilliseconds: 830);
      for (final duplicate in [
        fixture.carbs.copyWith(externalId: 'other-carbs'),
        fixture.insulin.copyWith(externalId: 'other-delivery'),
        fixture.wizard.copyWith(nightscoutObjectId: 'other-calculator'),
      ]) {
        for (final input in submissionOrders([
          fixture.wizard,
          fixture.insulin,
          fixture.carbs,
          duplicate,
        ])) {
          expect(BolusWizardGrouping(input).relatedRecords, isEmpty);
        }
      }
    },
  );

  test('requires valid carbohydrate and positive finite delivery records', () {
    final fixture = trailingSubmission();
    for (final insulin in [
      fixture.insulin.copyWith(isValid: false),
      fixture.insulin.copyWith(insulin: 0),
      fixture.insulin.copyWith(insulin: double.nan),
    ]) {
      expect(
        BolusWizardGrouping([
          fixture.wizard,
          insulin,
          fixture.carbs,
        ]).relatedRecords,
        isEmpty,
      );
    }
    expect(
      BolusWizardGrouping([
        fixture.wizard,
        fixture.insulin,
        fixture.carbs.copyWith(isValid: false),
      ]).relatedRecords,
      isEmpty,
    );
  });

  test('does not claim a second intake when leading carbs already match', () {
    final fixture = trailingSubmission();
    final leading = fixture.carbs.copyWith(
      externalId: 'leading-carbs',
      createdAt: fixture.wizard.createdAt.subtract(const Duration(seconds: 1)),
    );
    expect(
      BolusWizardGrouping([
        leading,
        fixture.wizard,
        fixture.insulin,
        fixture.carbs,
      ]).relatedRecords,
      {leading},
    );
  });
}

({BolusWizard wizard, ManualBolus insulin, Treat carbs}) trailingSubmission({
  int carbs = 48,
  double recommendation = 44.7,
  int deliveryDelayMilliseconds = 830,
  int carbDelayMilliseconds = 831,
}) {
  final time = DateTime.utc(2026, 1, 1, 12);
  final records = TreatmentFactory().parseTreatments([
    {
      '_id': 'calculator-$carbs',
      'eventType': 'Bolus Wizard',
      'created_at': time.toIso8601String(),
      'glucose': 125,
      'bolusCalculatorResult': {'carbs': carbs, 'totalInsulin': recommendation},
    },
    {
      '_id': 'delivery-$carbs',
      'eventType': 'Meal Bolus',
      'created_at': time
          .add(Duration(milliseconds: deliveryDelayMilliseconds))
          .toIso8601String(),
      'insulin': 3.0,
    },
    {
      '_id': 'carbs-$carbs',
      'eventType': 'Meal Bolus',
      'created_at': time
          .add(Duration(milliseconds: carbDelayMilliseconds))
          .toIso8601String(),
      'carbs': carbs,
    },
  ]);
  return (
    wizard: records.whereType<BolusWizard>().single,
    insulin: records.whereType<ManualBolus>().single,
    carbs: records.whereType<Treat>().single,
  );
}

Iterable<List<Treatment>> submissionOrders(List<Treatment> records) sync* {
  if (records.isEmpty) {
    yield [];
    return;
  }
  for (var index = 0; index < records.length; index++) {
    final rest = [...records]..removeAt(index);
    for (final tail in submissionOrders(rest)) {
      yield [records[index], ...tail];
    }
  }
}
