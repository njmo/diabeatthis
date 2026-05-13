import 'package:diabeatthis/core/data_sources/cloud/cloud_device_status_source_repository.dart';
import 'package:diabeatthis/core/data_sources/cloud/cloud_glucose_source_repository.dart';
import 'package:diabeatthis/core/data_sources/cloud/cloud_treatment_source_repository.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
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
  });
}

class _FakeNightscoutRepository implements NightscoutRepository {
  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) {
    throw UnimplementedError();
  }

  @override
  Future<DeviceStatus> fetchLastDeviceStatus() {
    throw UnimplementedError();
  }

  @override
  Future<TemporaryTarget> fetchLastTemporaryTarget() {
    throw UnimplementedError();
  }

  @override
  Future<TemporaryTarget> fetchLastTemporaryTargetById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<Glucose>> fetchGlucoseAfter(DateTime after) {
    throw UnimplementedError();
  }

  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    throw UnimplementedError();
  }

  @override
  Future<List<Glucose>> fetchGlucoseOnDay(DateTime day) {
    throw UnimplementedError();
  }

  @override
  Future<List<Glucose>> fetchLastGlucoseWithLimit(int limit) {
    throw UnimplementedError();
  }

  @override
  Future<List<Meal>> fetchMealsAfter(DateTime after) {
    throw UnimplementedError();
  }

  @override
  Future<List<Meal>> fetchMealsOnDay(DateTime day) {
    throw UnimplementedError();
  }

  @override
  Future<List<Treatment>> fetchTreatmentsAfter(DateTime after) {
    throw UnimplementedError();
  }

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end) {
    throw UnimplementedError();
  }

  @override
  Future<List<Treatment>> fetchTreatmentsOnDay(DateTime day) {
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
