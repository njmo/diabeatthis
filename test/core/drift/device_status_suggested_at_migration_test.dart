import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/core/data_sources/local_mirror/mappers/device_status_drift_mapper.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';

void main() {
  test('version 29 history gains nullable suggestion time safely', () async {
    final dir = await Directory.systemTemp.createTemp('suggested-at-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/history.sqlite');
    var db = DatabaseImpl(NativeDatabase(file));
    final envelopeAt = DateTime.utc(2026, 9, 15, 12);
    final predictedAt = envelopeAt.subtract(const Duration(minutes: 2));
    final withLegacyPrediction =
        testDeviceStatus(
          date: envelopeAt,
          iob: 0,
          cob: 0,
          tick: '0',
          bg: 100,
          carbsReq: 8,
        ).copyWith(
          suggestedAt: predictedAt,
          aapsPredictionsJson: jsonEncode({
            'timestamp': predictedAt.toIso8601String(),
            'predBGs': {
              'IOB': [100, 99],
            },
          }),
        );
    final withoutSuggestionTime = testDeviceStatus(
      date: envelopeAt.add(const Duration(minutes: 1)),
      iob: 0,
      cob: 0,
      tick: '0',
      bg: 100,
      carbsReq: 6,
    );
    await db.localMirrorDao.upsertDeviceStatus(
      withLegacyPrediction.toCompanion(),
    );
    await db.localMirrorDao.upsertDeviceStatus(
      withoutSuggestionTime.toCompanion(),
    );
    await db.customStatement(
      'ALTER TABLE device_status DROP COLUMN suggested_at',
    );
    await db.customStatement('PRAGMA user_version = 29');
    await db.close();

    db = DatabaseImpl(NativeDatabase(file));
    addTearDown(db.close);
    final rows = await db.select(db.deviceStatus).get();
    final restored = rows.map((row) => row.toDomain()).toList();

    expect(restored.first.suggestedAt, predictedAt);
    expect(restored.first.hasCarbsReq, true);
    expect(restored.last.suggestedAt, isNull);
    expect(restored.last.hasCarbsReq, false);
  });
}
