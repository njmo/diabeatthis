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
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/domain/model/device_status.dart' as domain;
import 'package:diabeatthis/core/domain/model/glucose.dart' as domain;
import 'package:diabeatthis/core/domain/model/temporary_target.dart' as domain;
import 'package:diabeatthis/core/domain/model/treatment_base.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
        container.read(treatmentSourceRepositoryProvider.future),
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
        container.read(treatmentSourceRepositoryProvider.future),
        completion(isA<MirroringTreatmentSourceRepository>()),
      );
      await expectLater(
        container.read(deviceStatusSourceRepositoryProvider.future),
        completion(isA<MirroringDeviceStatusSourceRepository>()),
      );
    });
  });
}

class _FakeNightscoutRepository implements NightscoutRepository {
  @override
  Future<domain.DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) {
    throw UnimplementedError();
  }

  @override
  Future<domain.DeviceStatus> fetchLastDeviceStatus() {
    throw UnimplementedError();
  }

  @override
  Future<domain.TemporaryTarget> fetchLastTemporaryTarget() {
    throw UnimplementedError();
  }

  @override
  Future<domain.TemporaryTarget> fetchLastTemporaryTargetById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Glucose>> fetchGlucoseAfter(DateTime after) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Glucose>> fetchGlucoseOnDay(DateTime day) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Glucose>> fetchLastGlucoseWithLimit(int limit) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.BolusWizard>> fetchBolusWizardsAfter(DateTime after) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.BolusWizard>> fetchBolusWizardsOnDay(DateTime day) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Treatment>> fetchTreatmentsAfter(DateTime after) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<domain.Treatment>> fetchTreatmentsOnDay(DateTime day) {
    throw UnimplementedError();
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
