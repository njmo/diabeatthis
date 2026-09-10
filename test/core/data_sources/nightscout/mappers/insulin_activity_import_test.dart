import 'dart:io';

import 'package:diabeatthis/core/data_sources/local_mirror/mappers/device_status_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/device_status_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/device_status_mapper.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/basal_schema_columns.dart';

void main() {
  const timestamp = '2026-09-09T10:00:00Z';
  const envelopeTime = '2026-09-09T10:04:00Z';
  DeviceStatus status({bool present = true, String? time = timestamp}) =>
      DeviceStatusDto(
        createdAt: envelopeTime,
        openaps: {
          'iob': {
            'iob': 1,
            if (present) 'activity': 0.0,
            if (time != null) 'time': time,
          },
        },
      ).toDomain();

  test('preserves model time separately from envelope and measured zero', () {
    final value = status();
    expect(value.date.toUtc(), DateTime.parse(envelopeTime));
    expect(value.insulinActivityAt, DateTime.parse(timestamp));
    expect(value.hasInsulinActivity, isTrue);
    expect(value.insulinActivity, 0);
    expect(status(present: false).hasInsulinActivity, isFalse);
    expect(status(time: null).insulinActivityAt, isNull);
    expect(status(time: 'invalid').insulinActivityAt, isNull);
  });
  test(
    'JSON and native AAPS round trips preserve missingness and model time',
    () {
      for (final present in [true, false]) {
        final value = status(present: present);
        final synchronized = DeviceStatus.fromJson(value.toJson());
        final native = LocalDeviceStatusEvent.fromJson(
          LocalDeviceStatusEvent(data: value).toJson(),
        ).data;
        for (final actual in [synchronized, native]) {
          expect(actual.hasInsulinActivity, present);
          expect(actual.insulinActivityAt, value.insulinActivityAt);
        }
      }
    },
  );
  test('Drift round trip preserves missing vs zero and timestamp', () async {
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    for (final present in [false, true]) {
      await db.localMirrorDao.upsertDeviceStatus(
        status(present: present).toCompanion(),
      );
      final row = await db.select(db.deviceStatus).getSingle();
      expect(row.insulinActivity, present ? 0 : null);
      final actual = row.toDomain();
      expect(actual.hasInsulinActivity, present);
      expect(actual.insulinActivityAt?.toUtc(), DateTime.parse(timestamp));
    }
  });
  test(
    'schema 20 upgrade preserves activity and leaves unknown time null',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'activity-migration-',
      );
      final file = File('${directory.path}/db.sqlite');
      var db = drift.DatabaseImpl(NativeDatabase(file));
      try {
        await db.localMirrorDao.upsertDeviceStatus(status().toCompanion());
        await db.customStatement(
          'ALTER TABLE device_status DROP COLUMN aaps_predictions_json',
        );
        await db.customStatement(
          'ALTER TABLE device_status DROP COLUMN insulin_activity_at',
        );
        for (final column in basalSchemaColumns) {
          await db.customStatement(
            'ALTER TABLE device_status DROP COLUMN $column',
          );
        }
        await db.customStatement('PRAGMA user_version = 20');
        await db.close();
        db = drift.DatabaseImpl(NativeDatabase(file));
        final row = await db.select(db.deviceStatus).getSingle();
        expect(row.insulinActivity, 0);
        expect(row.insulinActivityAt, isNull);
        await db.localMirrorDao.upsertDeviceStatus(status().toCompanion());
        expect(
          (await db.select(db.deviceStatus).getSingle()).insulinActivityAt,
          DateTime.parse(timestamp).millisecondsSinceEpoch,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
