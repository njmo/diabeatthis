import 'package:diabeatthis/core/data_sources/cloud/cloud_device_status_source_repository.dart';
import 'package:diabeatthis/core/data_sources/cloud/cloud_glucose_source_repository.dart';
import 'package:diabeatthis/core/data_sources/cloud/cloud_treatment_source_repository.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/repositories/mirroring_device_status_source_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/repositories/mirroring_glucose_source_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/repositories/mirroring_treatment_source_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/bolus_calculator_result.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/domain/model/correction_bolus.dart' as domain;
import 'package:diabeatthis/core/domain/model/device_status.dart' as domain;
import 'package:diabeatthis/core/domain/model/glucose.dart' as domain;
import 'package:diabeatthis/core/domain/model/temporary_target.dart' as domain;
import 'package:diabeatthis/core/domain/model/treatment_base.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/device_status_factory.dart';

void main() {
  group('source repository providers', () {
    test('uses cloud repositories for cloud config', () async {
      const config = DataSourceConfig.defaults();
      final nightscoutRepository = _FakeNightscoutRepository();
      final container = ProviderContainer(
        overrides: [
          dataSourceConfigProvider.overrideWithValue(const AsyncData(config)),
          nightscoutRepositoryProvider.overrideWithValue(
            AsyncData(nightscoutRepository),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(glucoseSourceRepositoryProvider.future),
        completion(isA<CloudGlucoseSourceRepository>()),
      );
      await expectLater(
        container.read(treatmentsSourceRepositoryProvider.future),
        completion(isA<CloudTreatmentSourceRepository>()),
      );
      await expectLater(
        container.read(deviceStatusSourceRepositoryProvider.future),
        completion(isA<CloudDeviceStatusSourceRepository>()),
      );
    });

    test('wraps cloud repositories when local mirror is enabled', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      const config = DataSourceConfig(
        bgSource: BgSource.cloud,
        eventSource: EventSource.cloud,
        pumpStatusSource: PumpStatusSource.cloud,
        historySource: HistorySource.cloud,
        mirrorToLocal: true,
      );
      final nightscoutRepository = _FakeNightscoutRepository();
      final container = ProviderContainer(
        overrides: [
          dataSourceConfigProvider.overrideWithValue(const AsyncData(config)),
          nightscoutRepositoryProvider.overrideWithValue(
            AsyncData(nightscoutRepository),
          ),
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(glucoseSourceRepositoryProvider.future),
        completion(isA<MirroringGlucoseSourceRepository>()),
      );
      await expectLater(
        container.read(treatmentsSourceRepositoryProvider.future),
        completion(isA<MirroringTreatmentSourceRepository>()),
      );
      await expectLater(
        container.read(deviceStatusSourceRepositoryProvider.future),
        completion(isA<MirroringDeviceStatusSourceRepository>()),
      );
    });

    test('uses pump status source independently from event source', () async {
      const config = DataSourceConfig(
        bgSource: BgSource.cloud,
        eventSource: EventSource.aaps,
        pumpStatusSource: PumpStatusSource.cloud,
        historySource: HistorySource.cloud,
        mirrorToLocal: false,
      );
      final nightscoutRepository = _FakeNightscoutRepository();
      final container = ProviderContainer(
        overrides: [
          dataSourceConfigProvider.overrideWithValue(const AsyncData(config)),
          nightscoutRepositoryProvider.overrideWithValue(
            AsyncData(nightscoutRepository),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(deviceStatusSourceRepositoryProvider.future),
        completion(isA<CloudDeviceStatusSourceRepository>()),
      );
    });

    test('mirrors cloud reads into local storage when enabled', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.fromMillisecondsSinceEpoch(1000);
      final glucose = domain.Glucose(
        externalId: 'glucose-1',
        source: domain.GlucoseSource.cloud,
        date: now,
        sgv: 123,
        direction: 'Flat',
      );
      final deviceStatus = testDeviceStatus(
        externalId: 'status-1',
        date: now,
        iob: 0.5,
        cob: 12,
        tick: '+1',
        bg: 123,
      );
      final bolusWizard = domain.BolusWizard(
        nightscoutObjectId: 'bolus-wizard-1',
        createdAt: now,
        date: now,
        glucose: 123,
        units: 'mg/dl',
        notes: null,
        calculatorResult: _testBolusCalculatorResult(
          carbs: 30,
          totalInsulin: 2.5,
        ),
      );
      final temporaryTarget = domain.TemporaryTarget(
        nightscoutId: 'target-1',
        createdAt: now.add(const Duration(minutes: 5)),
        durationInMiliseconds: Duration.minutesPerHour * 60 * 1000,
        duration: 60,
        targetBottom: 90,
        targetTop: 120,
      );
      final correctionBolus = domain.CorrectionBolus(
        externalId: 'correction-1',
        createdAt: now.add(const Duration(minutes: 6)),
        insulin: 0.7,
      );

      const config = DataSourceConfig(
        bgSource: BgSource.cloud,
        eventSource: EventSource.cloud,
        pumpStatusSource: PumpStatusSource.cloud,
        historySource: HistorySource.cloud,
        mirrorToLocal: true,
      );
      final nightscoutRepository = _FakeNightscoutRepository(
        glucoseReadings: [glucose],
        deviceStatuses: [deviceStatus],
        treatments: [bolusWizard, temporaryTarget, correctionBolus],
      );
      final container = ProviderContainer(
        overrides: [
          dataSourceConfigProvider.overrideWithValue(const AsyncData(config)),
          nightscoutRepositoryProvider.overrideWithValue(
            AsyncData(nightscoutRepository),
          ),
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final glucoseRepository = await container.read(
        glucoseSourceRepositoryProvider.future,
      );
      final treatmentRepository = await container.read(
        treatmentsSourceRepositoryProvider.future,
      );
      final deviceStatusRepository = await container.read(
        deviceStatusSourceRepositoryProvider.future,
      );

      final returnedGlucose = await glucoseRepository.pollGlucose();
      final returnedTreatments = await treatmentRepository.pollTreatments();
      final returnedDeviceStatus = await deviceStatusRepository
          .pollDeviceStatus();

      expect(returnedGlucose, glucose);
      expect(returnedTreatments, [
        bolusWizard,
        temporaryTarget,
        correctionBolus,
      ]);
      expect(returnedDeviceStatus, deviceStatus);

      final mirroredGlucose = await db.localMirrorDao.getGlucoseReadingsBetween(
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime.fromMillisecondsSinceEpoch(2000),
      );
      final mirroredStatuses = await db.localMirrorDao.getDeviceStatusesBetween(
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime.fromMillisecondsSinceEpoch(2000),
      );
      final mirroredBolusWizards = await db.localMirrorDao
          .getBolusWizardsBetween(
            DateTime.fromMillisecondsSinceEpoch(0),
            DateTime.fromMillisecondsSinceEpoch(2000),
          );
      final mirroredTargets = await db.localMirrorDao
          .getTemporaryTargetsBetween(
            DateTime.fromMillisecondsSinceEpoch(0),
            DateTime.fromMillisecondsSinceEpoch(400000),
          );
      final mirroredCorrectionBoluses = await db.localMirrorDao
          .getCorrectionBolusesBetween(
            DateTime.fromMillisecondsSinceEpoch(0),
            DateTime.fromMillisecondsSinceEpoch(500000),
          );

      expect(mirroredGlucose, hasLength(1));
      expect(mirroredGlucose.single.externalId, 'glucose-1');
      expect(mirroredGlucose.single.sgv, 123);

      expect(mirroredStatuses, hasLength(1));
      expect(mirroredStatuses.single.externalId, 'status-1');
      expect(mirroredStatuses.single.bg, 123);

      expect(mirroredBolusWizards, hasLength(1));
      expect(mirroredBolusWizards.single.externalId, 'bolus-wizard-1');
      expect(mirroredBolusWizards.single.carbs, 30);
      expect(mirroredBolusWizards.single.insulin, 2.5);

      expect(mirroredTargets, hasLength(1));
      expect(mirroredTargets.single.externalId, 'target-1');
      expect(mirroredTargets.single.targetBottom, 90);
      expect(mirroredTargets.single.targetTop, 120);

      expect(mirroredCorrectionBoluses, hasLength(1));
      expect(mirroredCorrectionBoluses.single.externalId, 'correction-1');
      expect(
        mirroredCorrectionBoluses.single.source,
        EventSource.cloud.storageValue,
      );
      expect(mirroredCorrectionBoluses.single.insulin, 0.7);
    });
  });
}

class _FakeNightscoutRepository implements NightscoutRepository {
  const _FakeNightscoutRepository({
    this.glucoseReadings = const [],
    this.deviceStatuses = const [],
    this.treatments = const [],
  });

  final List<domain.Glucose> glucoseReadings;
  final List<domain.DeviceStatus> deviceStatuses;
  final List<domain.Treatment> treatments;

  @override
  Future<domain.DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) {
    return Future.value(deviceStatuses.isEmpty ? null : deviceStatuses.last);
  }

  @override
  Future<domain.DeviceStatus> fetchLastDeviceStatus() {
    return Future.value(deviceStatuses.last);
  }

  @override
  Future<domain.TemporaryTarget> fetchLastTemporaryTarget() {
    return Future.value(treatments.whereType<domain.TemporaryTarget>().last);
  }

  @override
  Future<domain.TemporaryTarget> fetchLastTemporaryTargetById(String id) {
    return Future.value(
      treatments.whereType<domain.TemporaryTarget>().firstWhere(
        (target) => target.nightscoutId == id,
      ),
    );
  }

  @override
  Future<List<domain.DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) {
    return Future.value(deviceStatuses);
  }

  @override
  Future<List<domain.Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) {
    return Future.value(glucoseReadings);
  }

  @override
  Future<List<domain.Glucose>> fetchGlucoseAfter(DateTime after) {
    return Future.value(glucoseReadings);
  }

  @override
  Future<List<domain.Glucose>> fetchGlucoseOnDay(DateTime day) {
    return Future.value(glucoseReadings);
  }

  @override
  Future<List<domain.Glucose>> fetchLastGlucoseWithLimit(int limit) {
    return Future.value(glucoseReadings.take(limit).toList());
  }

  @override
  Future<List<domain.BolusWizard>> fetchBolusWizardsAfter(DateTime after) {
    return Future.value(treatments.whereType<domain.BolusWizard>().toList());
  }

  @override
  Future<List<domain.BolusWizard>> fetchBolusWizardsOnDay(DateTime day) {
    return Future.value(treatments.whereType<domain.BolusWizard>().toList());
  }

  @override
  Future<List<domain.Treatment>> fetchTreatmentsAfter(DateTime after) {
    return Future.value(treatments);
  }

  @override
  Future<List<domain.Treatment>> fetchTreatmentsOnDay(DateTime day) {
    return Future.value(treatments);
  }

  @override
  Future<List<domain.Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) {
    return Future.value(treatments);
  }

  @override
  Future<Duration?> getLatestInsulinChangeAge() {
    throw UnimplementedError();
  }

  @override
  Future<Duration?> getLatestSensorChangeAge() {
    throw UnimplementedError();
  }
}

BolusCalculatorResult _testBolusCalculatorResult({
  double? carbs,
  double? totalInsulin,
}) {
  return BolusCalculatorResult(
    id: null,
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
