import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide Meal;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late LocalMirrorWriter writer;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    writer = LocalMirrorWriter(db.localMirrorDao);
  });

  tearDown(() async {
    await db.close();
  });

  test('mirrors glucose readings into local storage', () async {
    final date = DateTime.fromMillisecondsSinceEpoch(1000);

    await writer.mirrorGlucose([
      Glucose(id: 0, date: date, sgv: 120, direction: 'Flat'),
      Glucose(id: 0, date: date, sgv: 120, direction: 'FortyFiveUp'),
    ], BgSource.cloud);

    final readings = await db.localMirrorDao.getGlucoseReadingsBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(2000),
    );

    expect(readings, hasLength(1));
    expect(readings.single.source, BgSource.cloud.storageValue);
    expect(readings.single.sgv, 120);
    expect(readings.single.direction, 'FortyFiveUp');
  });

  test('mirrors treatments with stable external ids', () async {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(1000);

    await writer.mirrorTreatments([
      Meal(
        id: 0,
        name: '',
        nightscoutObjectId: 'meal-1',
        createdAt: createdAt,
        carbs: 30,
        insulin: 2.5,
      ),
      TemporaryTarget(
        id: 0,
        nightscoutId: 'target-1',
        createdAt: createdAt.add(const Duration(minutes: 5)),
        durationInMiliseconds: 1800000,
        duration: 30,
        targetBottom: 90,
        targetTop: 120,
      ),
    ], EventSource.cloud);

    final events = await db.localMirrorDao.getTreatmentEventsBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(400000),
    );

    expect(events, hasLength(2));
    expect(events.first.externalId, 'meal-1');
    expect(events.first.treatmentType, 'Bolus Wizard');
    expect(events.first.carbs, 30);
    expect(events.first.insulin, 2.5);
    expect(events.last.externalId, 'target-1');
    expect(events.last.treatmentType, 'Temporary Target');
    expect(events.last.targetBottom, 90);
    expect(events.last.targetTop, 120);
  });

  test('mirrors device statuses into local storage', () async {
    final date = DateTime.fromMillisecondsSinceEpoch(1000);

    await writer.mirrorDeviceStatuses([
      DeviceStatus(id: 0, date: date, iob: 1.2, cob: 10, tick: '+1', bg: 110),
      DeviceStatus(id: 0, date: date, iob: 1.4, cob: 9, tick: '+2', bg: 111),
    ], EventSource.cloud);

    final statuses = await db.localMirrorDao.getDeviceStatusesBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(2000),
    );

    expect(statuses, hasLength(1));
    expect(statuses.single.source, EventSource.cloud.storageValue);
    expect(statuses.single.bg, 111);
    expect(statuses.single.iob, 1.4);
    expect(statuses.single.cob, 9);
    expect(statuses.single.tick, '+2');
  });
}
