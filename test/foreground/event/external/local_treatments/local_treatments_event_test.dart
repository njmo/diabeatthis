import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/foreground/event/external/external_event.dart';
import 'package:diabeatthis/foreground/event/external/local_treatments/local_treatments_event.dart';
import 'package:diabeatthis/foreground/event/external/native_receiver/native_receiver_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalTreatmentsEvent', () {
    test('parses a single treatment payload', () {
      final event = LocalTreatmentsEvent.fromJson(_carbCorrectionPayload());

      expect(event.data, hasLength(1));
      expect(event.data.single, isA<Treat>());
      expect((event.data.single as Treat).carbs, 12);
    });

    test('parses a wrapped treatment list payload', () {
      final event = LocalTreatmentsEvent.fromJson({
        'data': [_temporaryTargetPayload(), _carbCorrectionPayload()],
      });

      expect(event.data, hasLength(2));
      expect(event.data.first, isA<TemporaryTarget>());
      expect(event.data.last, isA<Treat>());
    });

    test('parses invalidated treatment as invalid domain data', () {
      final event = LocalTreatmentsEvent.fromJson({
        'data': [
          _carbCorrectionPayload(),
          {
            ..._carbCorrectionPayload(),
            '_id': 'removed-treat-1',
            'isValid': false,
          },
        ],
      });

      expect(event.data, hasLength(2));
      expect(event.data.first.isValid, isTrue);
      expect(event.data.last.isValid, isFalse);
    });

    test('parses AAPS external temporary target without Nightscout id', () {
      final event = LocalTreatmentsEvent.fromJson({
        'data': [_aapsExternalTemporaryTargetPayload()],
      });

      expect(event.data, hasLength(1));
      final target = event.data.single as TemporaryTarget;
      expect(target.nightscoutId, isNull);
      expect(target.duration, 30);
      expect(target.targetBottom, 90);
      expect(target.targetTop, 110);
    });

    test('parses AAPS external bolus wizard without Nightscout id', () {
      final event = LocalTreatmentsEvent.fromJson({
        'data': [_aapsExternalBolusWizardPayload()],
      });

      expect(event.data, hasLength(1));
      final wizard = event.data.single as BolusWizard;
      expect(wizard.nightscoutObjectId, isNull);
      expect(wizard.glucose, 123);
      expect(wizard.carbs, 18);
      expect(wizard.insulin, 1.2);
    });

    test('parses AAPS bolus wizard related treatments separately', () {
      final event = LocalTreatmentsEvent.fromJson({
        'data': [
          _aapsExternalMealBolusInsulinPayload(),
          _aapsExternalTemporaryBasalPayload(),
          _aapsExternalBolusWizardPayload(),
          _aapsExternalMealBolusCarbsPayload(),
        ],
      });

      expect(event.data, hasLength(3));
      expect(event.data.whereType<ManualBolus>(), hasLength(1));
      expect(event.data.whereType<BolusWizard>(), hasLength(1));
      expect(event.data.whereType<Treat>(), hasLength(1));
    });

    test('parses Nightscout bolus wizard related treatments separately', () {
      final event = LocalTreatmentsEvent.fromJson({
        'data': [
          _nightscoutMealBolusInsulinPayload(),
          _nightscoutBolusWizardPayload(),
          _nightscoutMealBolusCarbsPayload(),
        ],
      });

      expect(event.data, hasLength(3));
      expect(event.data.whereType<ManualBolus>(), hasLength(1));
      expect(event.data.whereType<Treat>(), hasLength(1));
      final wizard = event.data.whereType<BolusWizard>().single;
      expect(wizard.nightscoutObjectId, '6a0c9d3171dad4190366f427');
      expect(wizard.carbs, 23);
      expect(wizard.insulin, 0.85);
    });

    test('parses Nightscout carb correction near bolus wizard separately', () {
      final event = LocalTreatmentsEvent.fromJson({
        'data': [
          _nightscoutMealBolusInsulinPayload(),
          _nightscoutBolusWizardPayload(),
          _nightscoutCarbCorrectionPayload(),
        ],
      });

      expect(event.data, hasLength(3));
      expect(event.data.whereType<ManualBolus>(), hasLength(1));
      expect(event.data.whereType<BolusWizard>(), hasLength(1));
      expect(event.data.whereType<Treat>(), hasLength(1));
    });

    test('ignores unsupported AAPS external treatment records', () {
      final event = LocalTreatmentsEvent.fromJson({
        'data': [
          _aapsExternalTemporaryBasalPayload(),
          _carbCorrectionPayload(),
        ],
      });

      expect(event.data, hasLength(1));
      expect(event.data.single, isA<Treat>());
    });

    test('parses native receiver wrapper', () {
      final event = ExternalEvent.fromJson({
        'external_event': 'native_receiver',
        'data': {
          'kind': 'treatments',
          'data': {
            'data': [_temporaryTargetPayload()],
          },
        },
      });

      event.when(
        appEvent: (_) => fail('Expected native receiver event'),
        notificationEvent: (_) => fail('Expected native receiver event'),
        nativeReceiver: (nativeEvent) => nativeEvent.when(
          glucose: (_) => fail('Expected treatments receiver event'),
          deviceStatus: (_) => fail('Expected treatments receiver event'),
          treatments: (data) {
            expect(data.data, hasLength(1));
            expect(data.data.single, isA<TemporaryTarget>());
          },
        ),
      );
    });
  });
}

Map<String, dynamic> _carbCorrectionPayload() {
  return {
    '_id': 'treat-1',
    'eventType': 'Carb Correction',
    'created_at': '2026-05-18T21:10:00.000Z',
    'carbs': 12,
  };
}

Map<String, dynamic> _temporaryTargetPayload() {
  return {
    '_id': 'target-1',
    'eventType': 'Temporary Target',
    'created_at': '2026-05-18T21:12:00.000Z',
    'durationInMilliseconds': 1800000,
    'duration': 30,
    'targetBottom': 90,
    'targetTop': 110,
  };
}

Map<String, dynamic> _aapsExternalTemporaryTargetPayload() {
  return {
    'eventType': 'Temporary Target',
    'created_at': '2026-05-18T21:12:00.000Z',
    'timestamp': 1779129120000,
    'durationInMilliseconds': 1800000,
    'duration': 30,
    'targetBottom': 90,
    'targetTop': 110,
    'isValid': true,
  };
}

Map<String, dynamic> _aapsExternalBolusWizardPayload() {
  return {
    'eventType': 'Bolus Wizard',
    'created_at': '2026-05-18T21:15:00.000Z',
    'date': 1779129300000,
    'glucose': 123,
    'units': 'mg/dl',
    'bolusCalculatorResult': {'carbs': 18, 'totalInsulin': 1.2},
    'isValid': true,
  };
}

Map<String, dynamic> _aapsExternalMealBolusInsulinPayload() {
  return {
    'eventType': 'Meal Bolus',
    'created_at': '2026-05-18T21:15:01.000Z',
    'date': 1779129301000,
    'insulin': 1.2,
    'isValid': true,
  };
}

Map<String, dynamic> _nightscoutMealBolusInsulinPayload() {
  return {
    '_id': '6a0c9d3971dad4190366f428',
    'eventType': 'Meal Bolus',
    'insulin': 0.85,
    'created_at': '2026-05-19T17:26:17.374Z',
    'date': 1779211577374,
    'type': 'NORMAL',
    'isValid': true,
    'mills': 1779211577374,
    'carbs': null,
  };
}

Map<String, dynamic> _nightscoutBolusWizardPayload() {
  return {
    '_id': '6a0c9d3171dad4190366f427',
    'eventType': 'Bolus Wizard',
    'created_at': '2026-05-19T17:26:08.927Z',
    'isValid': true,
    'bolusCalculatorResult':
        '{"basalIOB":-0.358,"bolusIOB":0.747,"carbs":23.0,"carbsInsulin":1.3142857142857143,"cob":1.621249999999999,"cobInsulin":0.09264285714285708,"dateCreated":1779211568955,"glucoseDifference":15.0,"glucoseInsulin":0.08333333333333333,"glucoseTrend":-15.67,"glucoseValue":135.0,"ic":17.5,"id":1362,"ids":{},"isValid":true,"isf":180.0,"note":"","otherCorrection":0.0,"percentageCorrection":100,"profileName":"omnipod","superbolusInsulin":0.0,"targetBGHigh":120.0,"targetBGLow":92.0,"timestamp":1779211568927,"totalInsulin":0.85,"trendInsulin":-0.26116666666666666,"utcOffset":7200000,"version":0,"wasBasalIOBUsed":true,"wasBolusIOBUsed":true,"wasCOBUsed":true,"wasGlucoseUsed":true,"wasSuperbolusUsed":false,"wasTempTargetUsed":false,"wasTrendUsed":true,"wereCarbsUsed":true}',
    'date': 1779211568927,
    'glucose': 135,
    'units': 'mg/dl',
    'notes': '',
    'mills': 1779211568927,
    'carbs': null,
    'insulin': null,
  };
}

Map<String, dynamic> _nightscoutMealBolusCarbsPayload() {
  return {
    '_id': '6a0c9d5f71dad4190366f42a',
    'eventType': 'Meal Bolus',
    'carbs': 23,
    'notes': '',
    'created_at': '2026-05-19T17:26:07.842Z',
    'isValid': true,
    'date': 1779211567842,
    'mills': 1779211567842,
    'insulin': null,
  };
}

Map<String, dynamic> _nightscoutCarbCorrectionPayload() {
  return {
    '_id': '6a0c9d5f71dad4190366f42b',
    'eventType': 'Carb Correction',
    'carbs': 23,
    'notes': '',
    'created_at': '2026-05-19T17:26:07.842Z',
    'isValid': true,
    'date': 1779211567842,
    'mills': 1779211567842,
    'insulin': null,
  };
}

Map<String, dynamic> _aapsExternalMealBolusCarbsPayload() {
  return {
    'eventType': 'Meal Bolus',
    'created_at': '2026-05-18T21:15:02.000Z',
    'date': 1779129302000,
    'carbs': 18,
    'isValid': true,
  };
}

Map<String, dynamic> _aapsExternalTemporaryBasalPayload() {
  return {
    'eventType': 'Temp Basal',
    'created_at': '2026-05-18T21:20:00.000Z',
    'duration': 30,
    'durationInMilliseconds': 1800000,
    'rate': 0.35,
    'isValid': true,
  };
}
