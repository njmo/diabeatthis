import 'package:diabeatthis/core/data_sources/local_mirror/mappers/device_status_drift_mapper.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/device_status_factory.dart';

void main() {
  late DatabaseImpl db;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('preserves the suggestion timestamp used for freshness', () async {
    final envelopeAt = DateTime(2026, 9, 15, 12);
    final suggestedAt = envelopeAt.subtract(const Duration(minutes: 2));
    final status = testDeviceStatus(
      date: envelopeAt,
      iob: 0,
      cob: 0,
      tick: '0',
      bg: 100,
      carbsReq: 8,
    ).copyWith(suggestedAt: suggestedAt);

    await db.localMirrorDao.upsertDeviceStatus(status.toCompanion());
    final restored = (await db.select(db.deviceStatus).getSingle()).toDomain();

    expect(restored.suggestedAt, suggestedAt);
    expect(restored.hasCarbsReq, true);
    expect(restored.carbsReq, 8);
  });

  test(
    'does not treat a persisted request with unknown time as fresh',
    () async {
      final status = testDeviceStatus(
        date: DateTime(2026, 9, 15, 12),
        iob: 0,
        cob: 0,
        tick: '0',
        bg: 100,
        carbsReq: 8,
      );

      await db.localMirrorDao.upsertDeviceStatus(status.toCompanion());
      final restored = (await db.select(db.deviceStatus).getSingle())
          .toDomain();

      expect(restored.suggestedAt, isNull);
      expect(restored.hasCarbsReq, false);
    },
  );
}
