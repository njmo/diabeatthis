import 'package:diabeatthis/core/data_sources/nightscout/dto/device_status_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/device_status_mapper.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceStatusMapper', () {
    test('extracts total, basal and estimated bolus IOB', () {
      const dto = DeviceStatusDto(
        id: 'status-1',
        createdAt: '2026-05-14T08:42:16.418Z',
        pump: {
          'extended': {
            'LastBolus': '14.05.2026 10:07',
            'LastBolusAmount': 0.3,
            'TempBasalRemaining': 101,
            'BaseBasalRate': 0.4,
          },
        },
        openaps: {
          'suggested': {
            'bg': 66,
            'tick': '+4',
            'COB': 8.9,
            'IOB': 0.1,
            'carbsReq': 1,
            'carbsReqWithin': 0,
            'sensitivityRatio': 0.95,
            'isfMgdlForCarbs': 180,
          },
          'iob': {'iob': 0.275, 'basaliob': -0.324, 'activity': 0.0016},
        },
      );

      final status = dto.toDomain();

      expect(status.externalId, 'status-1');
      expect(status.source, DeviceStatusSource.cloud);
      expect(status.iob, 0.275);
      expect(status.basalIob, -0.324);
      expect(status.bolusIob, closeTo(0.599, 0.000001));
      expect(status.insulinActivity, 0.0016);
      expect(status.cob, 8.9);
      expect(status.tick, '+4');
      expect(status.bg, 66);
      expect(status.carbsReq, 1);
      expect(status.carbsReqWithin, 0);
      expect(status.sensitivityRatio, 0.95);
      expect(status.baseBasalRate, 0.4);
      expect(status.tempBasalRemainingMinutes, 101);
      expect(status.lastBolusAmount, 0.3);
      expect(status.lastBolusAt, '14.05.2026 10:07');
    });

    test('falls back to suggested IOB when detailed IOB is missing', () {
      const dto = DeviceStatusDto(
        createdAt: '2026-05-14T08:42:16.418Z',
        openaps: {
          'suggested': {'IOB': 0.3},
        },
      );

      final status = dto.toDomain();

      expect(status.iob, 0.3);
      expect(status.basalIob, 0);
      expect(status.bolusIob, 0.3);
      expect(status.insulinActivity, 0);
    });

    test('uses explicit source when provided', () {
      const dto = DeviceStatusDto(
        createdAt: '2026-05-14T08:42:16.418Z',
        openaps: {
          'suggested': {'IOB': 0.3},
        },
      );

      final status = dto.toDomain(source: DeviceStatusSource.aaps);

      expect(status.source, DeviceStatusSource.aaps);
    });
  });
}
