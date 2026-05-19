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
      GlucoseReadingCompanion.insert(
        source: BgSource.cloud.storageValue,
        externalId: const Value('sgv-1'),
        createdAt: const Value(1000),
        sgv: 120,
        direction: const Value('Flat'),
      ),
    );

    await db.localMirrorDao.upsertGlucoseReading(
      GlucoseReadingCompanion.insert(
        source: BgSource.cloud.storageValue,
        externalId: const Value('sgv-1'),
        createdAt: const Value(1000),
        sgv: 121,
        direction: const Value('FortyFiveUp'),
      ),
    );
    await db.localMirrorDao.upsertGlucoseReading(
      GlucoseReadingCompanion.insert(
        source: BgSource.xdrip.storageValue,
        createdAt: const Value(2000),
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
    await db.localMirrorDao.upsertManualBolus(
      ManualBolusCompanion.insert(
        source: TreatmentsSource.aaps.storageValue,
        externalId: const Value('treatment-1'),
        createdAt: const Value(1000),
        insulin: const Value(2.4),
      ),
    );
    await db.localMirrorDao.upsertTemporaryTarget(
      TemporaryTargetCompanion.insert(
        source: TreatmentsSource.cloud.storageValue,
        createdAt: const Value(2000),
        durationMinutes: const Value(30),
        targetBottom: const Value(90),
        targetTop: const Value(120),
      ),
    );

    final events = await db.localMirrorDao.getManualBolusesBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(1500),
      source: TreatmentsSource.aaps.storageValue,
    );

    expect(events, hasLength(1));
    expect(events.single.insulin, 2.4);
  });

  test('stores device statuses by source and created time', () async {
    await db.localMirrorDao.upsertDeviceStatus(
      DeviceStatusCompanion.insert(
        source: TreatmentsSource.aaps.storageValue,
        externalId: const Value('status-1'),
        createdAt: const Value(1000),
        bg: const Value(110),
        iob: const Value(1.3),
        basalIob: const Value(-0.2),
        bolusIob: const Value(1.5),
        insulinActivity: const Value(0.01),
        cob: const Value(18),
        carbsReq: const Value(4),
        carbsReqWithin: const Value(15),
        sensitivityRatio: const Value(0.95),
        isfMgdlForCarbs: const Value(180),
        baseBasalRate: const Value(0.4),
        tempBasalRemainingMinutes: const Value(101),
        lastBolusAmount: const Value(0.3),
        lastBolusAt: const Value('14.05.2026 10:07'),
      ),
    );
    await db.localMirrorDao.upsertDeviceStatus(
      DeviceStatusCompanion.insert(
        source: TreatmentsSource.cloud.storageValue,
        createdAt: const Value(2000),
        bg: const Value(140),
      ),
    );

    final statuses = await db.localMirrorDao.getDeviceStatusesBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(1500),
      source: TreatmentsSource.aaps.storageValue,
    );

    expect(statuses, hasLength(1));
    expect(statuses.single.bg, 110);
    expect(statuses.single.iob, 1.3);
    expect(statuses.single.basalIob, -0.2);
    expect(statuses.single.bolusIob, 1.5);
    expect(statuses.single.insulinActivity, 0.01);
    expect(statuses.single.cob, 18);
    expect(statuses.single.carbsReq, 4);
    expect(statuses.single.carbsReqWithin, 15);
    expect(statuses.single.sensitivityRatio, 0.95);
    expect(statuses.single.isfMgdlForCarbs, 180);
    expect(statuses.single.baseBasalRate, 0.4);
    expect(statuses.single.tempBasalRemainingMinutes, 101);
    expect(statuses.single.lastBolusAmount, 0.3);
    expect(statuses.single.lastBolusAt, '14.05.2026 10:07');
  });
}
