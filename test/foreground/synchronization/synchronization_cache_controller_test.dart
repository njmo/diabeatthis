import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/domain/device_status_history_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';

void main() {
  test('init does not fail when history sources are unavailable', () async {
    final container = ProviderContainer(
      overrides: [
        glucoseHistoryRepositoryProvider.overrideWith(
          (ref) async => _ThrowingGlucoseHistoryRepository(),
        ),
        deviceStatusHistoryRepositoryProvider.overrideWith(
          (ref) async => _ThrowingDeviceStatusHistoryRepository(),
        ),
        treatmentsHistoryRepositoryProvider.overrideWith(
          (ref) async => _ThrowingTreatmentsHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = SynchronizationCacheController();

    await expectLater(controller.init(container), completes);
    expect(controller.getCache().glucoseReadingsCache, isEmpty);
    expect(controller.getCache().deviceStatusCache, isNull);
    expect(controller.getCache().targetCache, isNull);
  });

  test('history load keeps live glucose readings already in cache', () async {
    final historyReading = Glucose(
      externalId: 'history',
      source: GlucoseSource.cloud,
      date: DateTime(2026, 5, 18, 12),
      sgv: 120,
      direction: 'Flat',
    );
    final liveReading = Glucose(
      externalId: 'xdrip',
      source: GlucoseSource.xdrip,
      date: DateTime(2026, 5, 18, 12, 5),
      sgv: 130,
      direction: 'Flat',
    );
    final container = ProviderContainer(
      overrides: [
        glucoseHistoryRepositoryProvider.overrideWith(
          (ref) async => _FakeGlucoseHistoryRepository([historyReading]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = SynchronizationCacheController();
    controller.cacheGlucose(liveReading);

    await controller.ensureGlucoseReadingsReady(container);

    expect(controller.getCache().glucoseReadingsCache, contains(liveReading));
    expect(
      controller.getCache().glucoseReadingsCache,
      contains(historyReading),
    );
  });

  test('loads latest device status from history into cache', () async {
    final deviceStatus = testDeviceStatus(
      externalId: 'history-device-status',
      date: DateTime(2026, 5, 18, 12),
      iob: 1,
      cob: 2,
      tick: '+1',
      bg: 120,
    );
    final container = ProviderContainer(
      overrides: [
        glucoseHistoryRepositoryProvider.overrideWith(
          (ref) async => const _FakeGlucoseHistoryRepository([]),
        ),
        deviceStatusHistoryRepositoryProvider.overrideWith(
          (ref) async => _FakeDeviceStatusHistoryRepository(deviceStatus),
        ),
        treatmentsHistoryRepositoryProvider.overrideWith(
          (ref) async => _FakeTreatmentsHistoryRepository(null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = SynchronizationCacheController();

    await controller.init(container);

    expect(controller.getCache().deviceStatusCache, deviceStatus);
  });

  test(
    'loads active temporary target from treatments history into cache',
    () async {
      final now = DateTime(2026, 5, 18, 12);
      final activeTarget = _temporaryTarget(
        id: 'active-target',
        createdAt: now.subtract(const Duration(minutes: 20)),
        duration: 60,
      );
      final repository = _FakeTreatmentsHistoryRepository(activeTarget);
      final container = ProviderContainer(
        overrides: [
          glucoseHistoryRepositoryProvider.overrideWith(
            (ref) async => const _FakeGlucoseHistoryRepository([]),
          ),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (ref) async => const _FakeDeviceStatusHistoryRepository(null),
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = SynchronizationCacheController();

      await withClock(Clock.fixed(now), () => controller.init(container));

      expect(controller.getCache().targetCache, activeTarget);
      expect(repository.lastTemporaryTargetReads, 1);
    },
  );
}

class _ThrowingGlucoseHistoryRepository implements GlucoseHistoryRepository {
  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    throw StateError('history unavailable');
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) {
    throw StateError('history unavailable');
  }
}

class _FakeGlucoseHistoryRepository implements GlucoseHistoryRepository {
  const _FakeGlucoseHistoryRepository(this._readings);

  final List<Glucose> _readings;

  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    return Future.value(_readings);
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) {
    return Future.value(_readings.take(limit).toList());
  }
}

class _ThrowingDeviceStatusHistoryRepository
    implements DeviceStatusHistoryRepository {
  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) {
    throw StateError('device status history unavailable');
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) {
    throw StateError('device status history unavailable');
  }
}

class _FakeDeviceStatusHistoryRepository
    implements DeviceStatusHistoryRepository {
  const _FakeDeviceStatusHistoryRepository(this._deviceStatus);

  final DeviceStatus? _deviceStatus;

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) {
    return Future.value(_deviceStatus == null ? [] : [_deviceStatus]);
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) {
    return Future.value(_deviceStatus);
  }
}

class _ThrowingTreatmentsHistoryRepository
    implements TreatmentsHistoryRepository {
  @override
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end) {
    throw StateError('treatments history unavailable');
  }

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() {
    throw StateError('treatments history unavailable');
  }
}

class _FakeTreatmentsHistoryRepository implements TreatmentsHistoryRepository {
  _FakeTreatmentsHistoryRepository(this._target);

  final TemporaryTarget? _target;
  var lastTemporaryTargetReads = 0;

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end) {
    throw StateError('temporary target cache should not fetch treatment lists');
  }

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() {
    lastTemporaryTargetReads++;
    return Future.value(_target);
  }
}

TemporaryTarget _temporaryTarget({
  required String id,
  required DateTime createdAt,
  required int duration,
}) {
  return TemporaryTarget(
    nightscoutId: id,
    createdAt: createdAt,
    durationInMiliseconds: duration * 60 * 1000,
    duration: duration,
    targetBottom: 90,
    targetTop: 110,
  );
}
