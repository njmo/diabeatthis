import 'package:diabeatthis/common/history/bolus_wizard_grouping.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final time = DateTime.utc(2026, 11, 2, 12);
  final wizard =
      TreatmentFactory().parseTreatments([
            {
              '_id': 'wizard',
              'eventType': 'Bolus Wizard',
              'created_at': time.toIso8601String(),
              'glucose': 120,
              'bolusCalculatorResult': {'carbs': 23, 'totalInsulin': 0.85},
            },
          ]).single
          as BolusWizard;
  final carbs = Treat(
    externalId: 'carbs',
    createdAt: time.subtract(const Duration(milliseconds: 1291)),
    carbs: 23,
  );
  final insulin = ManualBolus(
    externalId: 'delivery',
    createdAt: time.subtract(const Duration(milliseconds: 3)),
    insulin: 0.85,
  );

  test('recognizes complete AAPS pair timestamped just before wizard', () {
    final grouping = BolusWizardGrouping([wizard, insulin, carbs]);
    expect(grouping.relatedRecords, {carbs, insulin});
    expect(grouping.carbohydrateWizards[carbs], wizard);
  });

  test('requires full matching pair within the clock tolerance', () {
    for (final records in [
      [insulin, wizard],
      [carbs, insulin.copyWith(insulin: 0.5), wizard],
      [carbs, insulin.copyWith(isValid: false), wizard],
      [
        carbs,
        insulin.copyWith(
          createdAt: time.subtract(const Duration(milliseconds: 1001)),
        ),
        wizard,
      ],
      [carbs, carbs.copyWith(externalId: 'competing'), insulin, wizard],
    ]) {
      expect(BolusWizardGrouping(records).relatedRecords, isEmpty);
    }
  });
}
