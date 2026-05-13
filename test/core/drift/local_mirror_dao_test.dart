import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('upserts glucose readings and loads them by time range', () async {
    await db.localMirrorDao.upsertGlucoseReading(
      LocalGlucoseReadingCompanion.insert(
        source: BgSource.cloud.storageValue,
        externalId: const Value('sgv-1'),
        recordedAt: 1000,
        sgv: 120,
        direction: const Value('Flat'),
        rawJson: const Value('{"sgv":120}'),
      ),
    );

    await db.localMirrorDao.upsertGlucoseReading(
      LocalGlucoseReadingCompanion.insert(
        source: BgSource.cloud.storageValue,
        externalId: const Value('sgv-1'),
        recordedAt: 1000,
        sgv: 121,
        direction: const Value('FortyFiveUp'),
        rawJson: const Value('{"sgv":121}'),
      ),
    );
    await db.localMirrorDao.upsertGlucoseReading(
      LocalGlucoseReadingCompanion.insert(
        source: BgSource.xdrip.storageValue,
        recordedAt: 2000,
        sgv: 130,
      ),
    );

    final readings = await db.localMirrorDao.getGlucoseReadingsBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(1500),
      source: BgSource.cloud.storageValue,
    );

    expect(readings, hasLength(1));
    expect(readings.single.sgv, 121);
    expect(readings.single.direction, 'FortyFiveUp');
  });

  test('stores treatment events by source and created time', () async {
    await db.localMirrorDao.upsertTreatmentEvent(
      LocalTreatmentEventCompanion.insert(
        source: EventSource.aaps.storageValue,
        externalId: const Value('treatment-1'),
        treatmentType: 'Meal Bolus',
        createdAt: 1000,
        carbs: const Value(24),
        insulin: const Value(2.4),
      ),
    );
    await db.localMirrorDao.upsertTreatmentEvent(
      LocalTreatmentEventCompanion.insert(
        source: EventSource.cloud.storageValue,
        treatmentType: 'Temp Target',
        createdAt: 2000,
        targetBottom: const Value(90),
        targetTop: const Value(120),
      ),
    );

    final events = await db.localMirrorDao.getTreatmentEventsBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(1500),
      source: EventSource.aaps.storageValue,
    );

    expect(events, hasLength(1));
    expect(events.single.treatmentType, 'Meal Bolus');
    expect(events.single.carbs, 24);
    expect(events.single.insulin, 2.4);
  });

  test('stores device statuses by source and recorded time', () async {
    await db.localMirrorDao.upsertDeviceStatus(
      LocalDeviceStatusCompanion.insert(
        source: EventSource.aaps.storageValue,
        externalId: const Value('status-1'),
        recordedAt: 1000,
        bg: const Value(110),
        iob: const Value(1.3),
        cob: const Value(18),
        pumpJson: const Value('{"battery":80}'),
      ),
    );
    await db.localMirrorDao.upsertDeviceStatus(
      LocalDeviceStatusCompanion.insert(
        source: EventSource.cloud.storageValue,
        recordedAt: 2000,
        bg: const Value(140),
      ),
    );

    final statuses = await db.localMirrorDao.getDeviceStatusesBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(1500),
      source: EventSource.aaps.storageValue,
    );

    expect(statuses, hasLength(1));
    expect(statuses.single.bg, 110);
    expect(statuses.single.iob, 1.3);
    expect(statuses.single.cob, 18);
    expect(statuses.single.pumpJson, '{"battery":80}');
  });
}
