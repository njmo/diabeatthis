import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/core/data_sources/local_mirror/mappers/device_status_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/device_status_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/device_status_mapper.dart';
import 'package:diabeatthis/core/domain/model/aaps_prediction_snapshot.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/basal_schema_columns.dart';

void main() {
  final now = DateTime.utc(2026, 9, 9, 10);
  DeviceStatus status({
    DateTime? at,
    DateTime? modelAt,
    Map<String, List<num>>? series,
  }) => DeviceStatusDto(
    createdAt: (at ?? now).toIso8601String(),
    openaps: {
      'suggested': {
        'timestamp': (modelAt ?? now).toIso8601String(),
        'predBGs':
            series ?? {'IOB': List.filled(12, 60), 'COB': List.filled(12, 150)},
      },
    },
  ).toDomain();
  test('missing timestamp and invalid series are not synthesized', () {
    for (final value in [
      null,
      '{}',
      jsonEncode({
        'predBGs': {
          'IOB': [100, 90],
        },
      }),
      jsonEncode({
        'timestamp': now.toIso8601String(),
        'predBGs': {
          'IOB': [100, 'bad'],
        },
      }),
    ]) {
      expect(AapsPredictionSnapshot.decode(value), isNull);
    }
  });
  test('native and isolate JSON preserve prediction time and series', () {
    final original = status();
    for (final actual in [
      DeviceStatus.fromJson(original.toJson()),
      LocalDeviceStatusEvent.fromJson(
        LocalDeviceStatusEvent(data: original).toJson(),
      ).data,
    ]) {
      final decoded = AapsPredictionSnapshot.decode(
        actual.aapsPredictionsJson,
      )!;
      expect(decoded.calculatedAt, now);
      expect(decoded.series['COB'], List.filled(12, 150));
    }
  });
  test('Drift preserves predictions through provider storage path', () async {
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    await db.localMirrorDao.upsertDeviceStatus(status().toCompanion());
    final restored = (await db.select(db.deviceStatus).getSingle()).toDomain();
    expect(restored.aapsPredictionsJson, status().aapsPredictionsJson);
  });
  test('schema 21 migration leaves existing predictions unknown', () async {
    final dir = await Directory.systemTemp.createTemp('prediction-migration-');
    final file = File('${dir.path}/db');
    var db = drift.DatabaseImpl(NativeDatabase(file));
    try {
      await db.localMirrorDao.upsertDeviceStatus(status().toCompanion());
      await db.customStatement(
        'ALTER TABLE device_status DROP COLUMN aaps_predictions_json',
      );
      for (final column in basalSchemaColumns) {
        await db.customStatement(
          'ALTER TABLE device_status DROP COLUMN $column',
        );
      }
      await db.customStatement('PRAGMA user_version = 21');
      await db.close();
      db = drift.DatabaseImpl(NativeDatabase(file));
      expect(
        (await db.select(db.deviceStatus).getSingle()).aapsPredictionsJson,
        isNull,
      );
      await db.localMirrorDao.upsertDeviceStatus(status().toCompanion());
      expect(
        (await db.select(db.deviceStatus).getSingle()).aapsPredictionsJson,
        isNotNull,
      );
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
}
