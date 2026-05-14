import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/domain/model/bolus_calculator_result.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/domain/model/device_status.dart' as domain;
import 'package:diabeatthis/core/domain/model/glucose.dart' as domain;
import 'package:diabeatthis/core/domain/model/temporary_target.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/device_status_factory.dart';

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
      domain.Glucose(
        id: 0,
        externalId: null,
        source: domain.GlucoseSource.cloud,
        date: date,
        sgv: 120,
        direction: 'Flat',
      ),
      domain.Glucose(
        id: 0,
        externalId: null,
        source: domain.GlucoseSource.cloud,
        date: date,
        sgv: 120,
        direction: 'FortyFiveUp',
      ),
    ]);

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
      domain.BolusWizard(
        id: 0,
        nightscoutObjectId: 'meal-1',
        createdAt: createdAt,
        date: createdAt,
        glucose: 100,
        units: 'mg/dl',
        notes: null,
        calculatorResult: _testBolusCalculatorResult(
          carbs: 30,
          totalInsulin: 2.5,
        ),
      ),
      domain.TemporaryTarget(
        id: 0,
        nightscoutId: 'target-1',
        createdAt: createdAt.add(const Duration(minutes: 5)),
        durationInMiliseconds: 1800000,
        duration: 30,
        targetBottom: 90,
        targetTop: 120,
      ),
    ], EventSource.cloud);

    final bolusWizards = await db.localMirrorDao.getBolusWizardsBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(400000),
    );
    final temporaryTargets = await db.localMirrorDao.getTemporaryTargetsBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(400000),
    );

    expect(bolusWizards, hasLength(1));
    final bolusWizard = bolusWizards.single;
    expect(bolusWizard.nightscoutId, 'meal-1');
    expect(bolusWizard.externalId, 'meal-1');
    expect(bolusWizard.carbs, 30);
    expect(bolusWizard.insulin, 2.5);

    expect(temporaryTargets, hasLength(1));
    final temporaryTarget = temporaryTargets.single;
    expect(temporaryTarget.nightscoutId, 'target-1');
    expect(temporaryTarget.externalId, 'target-1');
    expect(temporaryTarget.targetBottom, 90);
    expect(temporaryTarget.targetTop, 120);
  });

  test('mirrors device statuses into local storage', () async {
    final date = DateTime.fromMillisecondsSinceEpoch(1000);

    await writer.mirrorDeviceStatuses([
      testDeviceStatus(
        id: 0,
        date: date,
        iob: 1.2,
        cob: 10,
        tick: '+1',
        bg: 110,
      ),
      testDeviceStatus(
        id: 0,
        externalId: 'status-1',
        source: domain.DeviceStatusSource.aaps,
        date: date,
        iob: 1.4,
        basalIob: -0.2,
        bolusIob: 1.6,
        insulinActivity: 0.01,
        cob: 9,
        tick: '+2',
        bg: 111,
        carbsReq: 4,
        carbsReqWithin: 15,
      ),
    ]);

    final statuses = await db.localMirrorDao.getDeviceStatusesBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(2000),
    );

    expect(statuses, hasLength(2));

    final aapsStatus = statuses.singleWhere(
      (status) => status.source == domain.DeviceStatusSource.aaps.storageValue,
    );
    expect(aapsStatus.source, domain.DeviceStatusSource.aaps.storageValue);
    expect(aapsStatus.bg, 111);
    expect(aapsStatus.externalId, 'status-1');
    expect(aapsStatus.iob, 1.4);
    expect(aapsStatus.basalIob, -0.2);
    expect(aapsStatus.bolusIob, 1.6);
    expect(aapsStatus.insulinActivity, 0.01);
    expect(aapsStatus.cob, 9);
    expect(aapsStatus.tick, '+2');
    expect(aapsStatus.carbsReq, 4);
    expect(aapsStatus.carbsReqWithin, 15);
  });
}

BolusCalculatorResult _testBolusCalculatorResult({
  double? carbs,
  double? totalInsulin,
}) {
  return BolusCalculatorResult(
    basalIob: null,
    bolusIob: null,
    carbs: carbs,
    carbsInsulin: null,
    cob: null,
    cobInsulin: null,
    dateCreated: null,
    glucoseDifference: null,
    glucoseInsulin: null,
    glucoseTrend: null,
    glucoseValue: null,
    ic: null,
    id: null,
    isf: null,
    note: null,
    otherCorrection: null,
    percentageCorrection: null,
    profileName: null,
    superbolusInsulin: null,
    targetBGHigh: null,
    targetBGLow: null,
    timestamp: null,
    totalInsulin: totalInsulin,
    trendInsulin: null,
    utcOffset: null,
    version: null,
    wasBasalIOBUsed: null,
    wasBolusIOBUsed: null,
    wasCOBUsed: null,
    wasGlucoseUsed: null,
    wasSuperbolusUsed: null,
    wasTempTargetUsed: null,
    wasTrendUsed: null,
    wereCarbsUsed: null,
  );
}
