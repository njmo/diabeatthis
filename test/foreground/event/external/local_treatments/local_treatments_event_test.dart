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
