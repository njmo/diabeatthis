import 'dart:io';

import 'package:diabeatthis/common/history/insulin_basal_summary.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/device_status_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/device_status_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/device_status_mapper.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/basal_schema_columns.dart';

DeviceStatus basalStatus({double? rate}) => DeviceStatusDto(
  createdAt: '2026-09-10T09:27:18.426Z',
  pump: {
    'clock': '2026-09-10T09:27:18.437Z',
    'extended': {
      'BaseBasalRate': 0.4,
      'TempBasalRemaining': 29,
      'TempBasalStart': '10.09.2026 11:27',
      if (rate != null) 'TempBasalAbsoluteRate': rate,
    },
  },
  openaps: {
    'enacted': {
      'timestamp': '2026-09-10T09:27:01.219Z',
      'rate': 0,
      'duration': 30,
      'received': true,
    },
  },
).toDomain();

void main() {
  test('ongoing zero basal survives JSON and Drift without enacted', () async {
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final status = const DeviceStatusDto(
      createdAt: '2026-09-10T09:27:18Z',
      pump: {
        'clock': '2026-09-10T09:27:18Z',
        'extended': {
          'BaseBasalRate': 0.4,
          'TempBasalStart': '10.09.2026 11:00',
          'TempBasalRemaining': 15,
        },
      },
    ).toDomain();
    final forwarded = LocalDeviceStatusEvent.fromJson(
      LocalDeviceStatusEvent(data: status).toJson(),
    ).data;
    await db.localMirrorDao.upsertDeviceStatus(forwarded.toCompanion());
    final restored = (await db.select(db.deviceStatus).getSingle()).toDomain();
    final summary = InsulinBasalSummary.calculate(
      [restored],
      status.date,
      status.date.add(const Duration(minutes: 5)),
    );
    expect(restored.enactedBasalAt, isNull);
    expect(restored.tempBasalAbsoluteRate, isNull);
    expect(summary.coverage, 1);
    expect(summary.units, 0);
    expect(summary.reducedUnits, closeTo(0.4 / 12, 1e-9));
  });
  test('mapper and foreground JSON preserve absent versus explicit zero', () {
    for (final rate in [null, 0.0, 0.35]) {
      final status = basalStatus(rate: rate);
      expect(status.tempBasalAbsoluteRate, rate);
      expect(status.enactedBasalReceived, true);
      expect(status.enactedBasalRate, 0);
      expect(status.enactedBasalDurationMinutes, 30);
      expect(
        status.basalObservedAt,
        DateTime.parse('2026-09-10T09:27:18.437Z'),
      );
      expect(DeviceStatus.fromJson(status.toJson()), status);
      expect(
        LocalDeviceStatusEvent.fromJson(
          LocalDeviceStatusEvent(data: status).toJson(),
        ).data,
        status.copyWith(source: DeviceStatusSource.aaps),
      );
    }
    expect(
      const DeviceStatusDto(
        createdAt: '2026-09-10T09:27:18Z',
      ).toDomain().basalObservedAt,
      isNull,
    );
  });
  test(
    'schema 23 upgrade preserves old data, new observations round trip',
    () async {
      final dir = await Directory.systemTemp.createTemp('basal-migration-');
      final file = File('${dir.path}/db');
      var db = drift.DatabaseImpl(NativeDatabase(file));
      try {
        await db.localMirrorDao.upsertDeviceStatus(basalStatus().toCompanion());
        for (final column in basalSchemaColumns) {
          await db.customStatement(
            'ALTER TABLE device_status DROP COLUMN $column',
          );
        }
        await db.customStatement('PRAGMA user_version = 23');
        await db.close();
        db = drift.DatabaseImpl(NativeDatabase(file));
        final legacy = (await db.select(db.deviceStatus).getSingle())
            .toDomain();
        expect(legacy.baseBasalRate, 0.4);
        expect(legacy.basalObservedAt, isNull);
        expect(legacy.tempBasalAbsoluteRate, isNull);
        for (final rate in [null, 0.0, 0.35]) {
          final status = basalStatus(rate: rate);
          await db.localMirrorDao.upsertDeviceStatus(status.toCompanion());
          expect(
            (await db.select(db.deviceStatus).getSingle()).toDomain(),
            status,
          );
        }
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
