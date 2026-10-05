import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';

void main() {
  test('preserves an unavailable carbs request through local JSON', () {
    final status = testDeviceStatus(
      date: DateTime(2026, 9, 15, 12),
      iob: 0,
      cob: 0,
      tick: '0',
      bg: 100,
      carbsReq: 0,
    ).copyWith(hasCarbsReq: false);

    final roundTrip = LocalDeviceStatusEvent.fromJson(
      LocalDeviceStatusEvent(data: status).toJson(),
    ).data;

    expect(roundTrip.hasCarbsReq, false);
    expect(roundTrip.carbsReq, 0);
  });

  test('complete suggested payload without carbsReq is explicit zero', () {
    final event = LocalDeviceStatusEvent.fromJson({
      'created_at': '2026-09-15T12:00:00.000Z',
      'openaps': {
        'suggested': {'bg': 100},
      },
    });

    expect(event.data.hasCarbsReq, true);
    expect(event.data.carbsReq, 0);
  });

  test('missing suggested payload is unavailable', () {
    final event = LocalDeviceStatusEvent.fromJson({
      'created_at': '2026-09-15T12:00:00.000Z',
    });

    expect(event.data.hasCarbsReq, false);
  });
}
