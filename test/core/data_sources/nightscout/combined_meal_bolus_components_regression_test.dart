import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final valid in [true, false]) {
    test(
      'combined delivery preserves both components without counting the calculator twice; valid=$valid',
      () {
        final at = DateTime.utc(2026, 11, 3, 12);
        final records = TreatmentFactory().parseTreatments([
          <String, dynamic>{
            '_id': 'wizard-1',
            'eventType': 'Bolus Wizard',
            'created_at': at
                .subtract(const Duration(seconds: 1))
                .toIso8601String(),
            'glucose': 120,
            'bolusCalculatorResult': {'carbs': 15, 'totalInsulin': 2.0},
            'isValid': valid,
          },
          <String, dynamic>{
            '_id': 'delivery-1',
            'eventType': 'Meal Bolus',
            'created_at': at.toIso8601String(),
            'insulin': 2.0,
            'duration': 0,
            'carbs': 15,
            'isValid': valid,
          },
        ], remoteSource: 'https://example.invalid');
        expect(records, hasLength(3));
        expect(
          records.whereType<ManualBolus>().single.externalId,
          'delivery-1',
        );
        expect(records.whereType<Treat>().single.externalId, 'delivery-1');
        expect(records.whereType<Treat>().single.carbs, 15);
        expect(
          records.whereType<BolusWizard>().single.remoteSource,
          'https://example.invalid',
        );
        final summary = InsulinBolusSummary.fromTreatments(
          treatments: records,
          start: at.subtract(const Duration(minutes: 1)),
          end: at.add(const Duration(minutes: 1)),
        );
        expect(summary.units, valid ? 2 : 0);
        expect(summary.count, valid ? 1 : 0);
      },
    );
  }
}
