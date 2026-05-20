import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TreatmentFactory', () {
    test('keeps Nightscout ids for cloud treatments', () {
      final treatments = TreatmentFactory().parseTreatments([
        _temporaryTargetPayload(id: 'target-1'),
        _bolusWizardPayload(id: 'wizard-1'),
        _manualBolusPayload(id: 'manual-1', createdAt: _iso(5)),
        _carbCorrectionPayload(id: 'treat-1', createdAt: _iso(6)),
      ]);

      expect(treatments, hasLength(4));
      expect((treatments[0] as TemporaryTarget).nightscoutId, 'target-1');
      expect((treatments[1] as BolusWizard).nightscoutObjectId, 'wizard-1');
      expect((treatments[2] as ManualBolus).externalId, 'manual-1');
      expect((treatments[3] as Treat).externalId, 'treat-1');
    });

    test('returns null ids when Nightscout id is missing', () {
      final treatments = TreatmentFactory().parseTreatments([
        _temporaryTargetPayload(id: null),
        _bolusWizardPayload(id: null),
      ]);

      expect((treatments[0] as TemporaryTarget).nightscoutId, isNull);
      expect((treatments[1] as BolusWizard).nightscoutObjectId, isNull);
    });

    test('keeps bolus wizard related records as separate treatments', () {
      final treatments = TreatmentFactory().parseTreatments([
        _manualBolusPayload(
          id: 'wizard-insulin',
          createdAt: _iso(1, seconds: 1),
        ),
        _bolusWizardPayload(id: 'wizard-1'),
        _carbCorrectionPayload(
          id: 'wizard-carbs',
          createdAt: _iso(1, seconds: 2),
        ),
        _manualBolusPayload(id: 'manual-1', createdAt: _iso(5)),
        _carbCorrectionPayload(id: 'treat-1', createdAt: _iso(6)),
      ]);

      expect(treatments, hasLength(5));
      expect(treatments.whereType<BolusWizard>(), hasLength(1));
      expect(
        treatments.whereType<ManualBolus>().map((bolus) => bolus.externalId),
        containsAll(['wizard-insulin', 'manual-1']),
      );
      expect(
        treatments.whereType<Treat>().map((treat) => treat.externalId),
        containsAll(['wizard-carbs', 'treat-1']),
      );
    });

    test('keeps SMB and manual entries near Bolus Wizard', () {
      final treatments = TreatmentFactory().parseTreatments([
        _bolusWizardPayload(id: 'wizard-1'),
        _manualBolusPayload(
          id: 'smb-1',
          createdAt: _iso(1, seconds: 1),
          insulin: 0.2,
          isSmb: true,
        ),
        _manualBolusPayload(
          id: 'manual-1',
          createdAt: _iso(1, seconds: 2),
          insulin: 0.4,
        ),
        _carbCorrectionPayload(
          id: 'treat-1',
          createdAt: _iso(1, seconds: 3),
          carbs: 7,
        ),
      ]);

      expect(treatments, hasLength(4));
      expect(treatments.whereType<BolusWizard>(), hasLength(1));
      expect(
        treatments.whereType<ManualBolus>().map((bolus) => bolus.externalId),
        containsAll(['smb-1', 'manual-1']),
      );
      expect(treatments.whereType<Treat>().single.externalId, 'treat-1');
    });
  });
}

Map<String, dynamic> _temporaryTargetPayload({required String? id}) {
  return {
    if (id != null) '_id': id,
    'eventType': 'Temporary Target',
    'created_at': _iso(0),
    'durationInMilliseconds': 1800000,
    'duration': 30,
    'targetBottom': 90,
    'targetTop': 110,
    'isValid': true,
  };
}

Map<String, dynamic> _bolusWizardPayload({required String? id}) {
  return {
    if (id != null) '_id': id,
    'eventType': 'Bolus Wizard',
    'created_at': _iso(1),
    'date': _date(1).millisecondsSinceEpoch,
    'glucose': 135,
    'units': 'mg/dl',
    'bolusCalculatorResult': {'carbs': 23.0, 'totalInsulin': 0.85},
    'isValid': true,
  };
}

Map<String, dynamic> _manualBolusPayload({
  required String id,
  required String createdAt,
  double insulin = 0.85,
  bool isSmb = false,
}) {
  return {
    '_id': id,
    'eventType': 'Meal Bolus',
    'created_at': createdAt,
    'date': DateTime.parse(createdAt).millisecondsSinceEpoch,
    'insulin': insulin,
    'carbs': null,
    'isSMB': isSmb,
    'isValid': true,
  };
}

Map<String, dynamic> _carbCorrectionPayload({
  required String id,
  required String createdAt,
  int carbs = 23,
}) {
  return {
    '_id': id,
    'eventType': 'Carb Correction',
    'created_at': createdAt,
    'date': DateTime.parse(createdAt).millisecondsSinceEpoch,
    'carbs': carbs,
    'insulin': null,
    'isValid': true,
  };
}

String _iso(int minutes, {int seconds = 0}) {
  return _date(minutes, seconds: seconds).toIso8601String();
}

DateTime _date(int minutes, {int seconds = 0}) {
  return DateTime.utc(2026, 5, 19, 17, 26 + minutes, seconds);
}
