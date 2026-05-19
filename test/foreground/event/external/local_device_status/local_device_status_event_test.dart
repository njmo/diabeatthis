import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/foreground/event/external/external_event.dart';
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_event.dart';
import 'package:diabeatthis/foreground/event/external/native_receiver/native_receiver_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDeviceStatusEvent', () {
    test('maps AAPS device status payload to device status', () {
      final event = LocalDeviceStatusEvent.fromJson(_deviceStatusJson());

      expect(event.data.externalId, 'status-1');
      expect(event.data.source, DeviceStatusSource.aaps);
      expect(
        event.data.date,
        DateTime.parse('2026-05-18T21:41:55.000Z').toLocal(),
      );
      expect(event.data.iob, 0.663);
      expect(event.data.basalIob, -0.214);
      expect(event.data.bolusIob, closeTo(0.877, 0.000001));
      expect(event.data.insulinActivity, 0.0116);
      expect(event.data.cob, 17.94);
      expect(event.data.tick, '+15');
      expect(event.data.bg, 249);
      expect(event.data.carbsReq, 3);
      expect(event.data.baseBasalRate, 0.35);
      expect(event.data.tempBasalRemainingMinutes, 95);
      expect(event.data.lastBolusAmount, 0.8);
      expect(event.data.lastBolusAt, '18.05.2026 19:50');
    });

    test('parses external event wrapper', () {
      final event = ExternalEvent.fromJson({
        'external_event': 'native_receiver',
        'data': {'kind': 'device_status', 'data': _deviceStatusJson()},
      });

      event.when(
        appEvent: (_) => fail('Expected local device status event'),
        notificationEvent: (_) => fail('Expected local device status event'),
        nativeReceiver: (data) => data.when(
          glucose: (_) => fail('Expected local device status event'),
          deviceStatus: (data) {
            expect(data.data.source, DeviceStatusSource.aaps);
            expect(data.data.bg, 249);
          },
          treatments: (_) => fail('Expected local device status event'),
        ),
      );
    });
  });
}

Map<String, dynamic> _deviceStatusJson() {
  return {
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
    'pump': {
      'extended': {
        'BaseBasalRate': 0.35,
        'TempBasalRemaining': 95,
        'LastBolusAmount': 0.8,
        'LastBolus': '18.05.2026 19:50',
      },
    },
  };
}
