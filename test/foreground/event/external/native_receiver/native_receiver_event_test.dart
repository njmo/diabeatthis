import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/foreground/event/external/native_receiver/native_receiver_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NativeReceiverEvent', () {
    test('parses glucose receiver event', () {
      final timestamp = DateTime(2026, 5, 18, 12, 30).millisecondsSinceEpoch;

      final event = NativeReceiverEvent.fromJson({
        'kind': 'glucose',
        'data': {
          'externalId': 'xdrip-$timestamp',
          'source': 'xdrip',
          'timestamp': timestamp,
          'sgv': 143,
          'direction': 'FortyFiveUp',
        },
      });

      event.when(
        glucose: (data) {
          expect(data.data.source, GlucoseSource.xdrip);
          expect(data.data.sgv, 143);
        },
        deviceStatus: (_) => fail('Expected glucose receiver event'),
        treatments: (_) => fail('Expected glucose receiver event'),
      );
    });

    test('parses device status receiver event', () {
      final event = NativeReceiverEvent.fromJson({
        'kind': 'device_status',
        'data': {
          '_id': 'status-1',
          'created_at': '2026-05-18T21:41:55.000Z',
          'openaps': {
            'suggested': {
              'bg': 249,
              'tick': '+15',
              'COB': 17.94,
              'IOB': 0.663,
              'carbsReq': 3,
              'carbsReqWithin': 0,
              'sensitivityRatio': 1,
              'isfMgdlForCarbs': 180,
            },
            'iob': {'iob': 0.663, 'basaliob': -0.214, 'activity': 0.0116},
          },
        },
      });

      event.when(
        glucose: (_) => fail('Expected device status receiver event'),
        deviceStatus: (data) {
          expect(data.data.source, DeviceStatusSource.aaps);
          expect(data.data.bg, 249);
        },
        treatments: (_) => fail('Expected device status receiver event'),
      );
    });
  });
}
