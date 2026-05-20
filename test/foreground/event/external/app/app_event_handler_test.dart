import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/app/execute_command_event.dart';
import 'package:diabeatthis/common/events/data/app/sync_data_key.dart';
import 'package:diabeatthis/common/events/data/task/task_data_synchronization_payload.dart';
import 'package:diabeatthis/common/events/task_event_payload.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/domain/device_status_history_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/device_status_source_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/foreground/event/external/app/app_event.dart';
import 'package:diabeatthis/foreground/event/external/app/app_event_handler.dart';
import 'package:diabeatthis/foreground/event/router/task_event_router.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/device_status_factory.dart';
import '../../../utils/fake_runtime_harness.dart';

void main() {
  group('AppEventHandler', () {
    test('syncs glucose from history after clearing settings cache', () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 5, 18, 21, 30);
      final cachedGlucose = Glucose(
        externalId: 'cached-glucose',
        source: GlucoseSource.cloud,
        date: now.subtract(const Duration(minutes: 5)),
        sgv: 112,
        direction: 'Flat',
      );
      final historyGlucose = Glucose(
        externalId: 'history-glucose',
        source: GlucoseSource.cloud,
        date: now.subtract(const Duration(minutes: 7)),
        sgv: 109,
        direction: 'Flat',
      );
      final router = RecordingTaskEventRouter();
      final glucoseHistoryRepository = _FakeGlucoseHistoryRepository([
        historyGlucose,
      ]);
      final container = ProviderContainer(
        overrides: [
          glucoseHistoryRepositoryProvider.overrideWith(
            (_) async => glucoseHistoryRepository,
          ),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (_) async => const _EmptyDeviceStatusHistoryRepository(),
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (_) async => const _EmptyTreatmentsHistoryRepository(),
          ),
          deviceStatusSourceRepositoryProvider.overrideWith(
            (_) async => const _ThrowingDeviceStatusSourceRepository(),
          ),
          taskEventRouterProvider.overrideWithValue(router),
        ],
      );
      container
          .read(synchronizationCacheControllerProvider)
          .cacheGlucose(cachedGlucose);
      final harness = FakeRuntimeHarness(container: container);

      await withClock(Clock.fixed(now), () async {
        AppEventHandler().handle(
          const AppEvent.executeCommand(
            data: ExecuteCommandEvent.syncSettings(data: {}),
          ),
          harness.runtimeContext,
        );
        await _waitForPayload(router);
      });

      expect(router.payloads, [
        TaskDataSynchronizationPayload.list(
          data: [TaskGlucoseSynchronization(data: historyGlucose)],
        ),
      ]);
      expect(glucoseHistoryRepository.requestedRecentLimit, 10);
      expect(
        container
            .read(synchronizationCacheControllerProvider)
            .getCache()
            .glucoseReadingsCache
            .toList(),
        [historyGlucose],
      );

      await harness.dispose();
    });

    test(
      'syncs device status from history after clearing settings cache',
      () async {
        SharedPreferences.setMockInitialValues({});
        final now = DateTime(2026, 5, 18, 21, 30);
        final cachedDeviceStatus = testDeviceStatus(
          date: now.subtract(const Duration(minutes: 8)),
          iob: 0.5,
          cob: 10,
          tick: '+2',
          bg: 101,
        );
        final historyDeviceStatus = testDeviceStatus(
          date: now.subtract(const Duration(minutes: 6)),
          iob: 0.6,
          cob: 12,
          tick: '+4',
          bg: 104,
        );
        final router = RecordingTaskEventRouter();
        final deviceStatusHistoryRepository =
            _FakeDeviceStatusHistoryRepository(historyDeviceStatus);
        final container = ProviderContainer(
          overrides: [
            glucoseHistoryRepositoryProvider.overrideWith(
              (_) async => const _EmptyGlucoseHistoryRepository(),
            ),
            deviceStatusHistoryRepositoryProvider.overrideWith(
              (_) async => deviceStatusHistoryRepository,
            ),
            treatmentsHistoryRepositoryProvider.overrideWith(
              (_) async => const _EmptyTreatmentsHistoryRepository(),
            ),
            deviceStatusSourceRepositoryProvider.overrideWith(
              (_) async => const _ThrowingDeviceStatusSourceRepository(),
            ),
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
        container
            .read(synchronizationCacheControllerProvider)
            .cacheDeviceStatus(cachedDeviceStatus);
        final harness = FakeRuntimeHarness(container: container);

        await withClock(Clock.fixed(now), () async {
          AppEventHandler().handle(
            const AppEvent.executeCommand(
              data: ExecuteCommandEvent.syncSettings(data: {}),
            ),
            harness.runtimeContext,
          );
          await _waitForPayload(router);
        });

        expect(router.payloads, [
          TaskDataSynchronizationPayload.list(
            data: [TaskDeviceStatusSynchronization(data: historyDeviceStatus)],
          ),
        ]);
        expect(deviceStatusHistoryRepository.requestedBefore, now);
        expect(
          container
              .read(synchronizationCacheControllerProvider)
              .getCache()
              .deviceStatusCache,
          historyDeviceStatus,
        );

        await harness.dispose();
      },
    );

    test(
      'loads requested device status from history when cache is empty',
      () async {
        SharedPreferences.setMockInitialValues({});
        final now = DateTime(2026, 5, 18, 21, 30);
        final historyDeviceStatus = testDeviceStatus(
          date: now.subtract(const Duration(minutes: 4)),
          iob: 0.7,
          cob: 13,
          tick: '+5',
          bg: 105,
        );
        final router = RecordingTaskEventRouter();
        final deviceStatusHistoryRepository =
            _FakeDeviceStatusHistoryRepository(historyDeviceStatus);
        final container = ProviderContainer(
          overrides: [
            deviceStatusHistoryRepositoryProvider.overrideWith(
              (_) async => deviceStatusHistoryRepository,
            ),
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);

        await withClock(Clock.fixed(now), () async {
          AppEventHandler().handle(
            const AppEvent.executeCommand(
              data: ExecuteCommandEvent.syncData(
                data: [SyncDataKey.deviceStatus],
              ),
            ),
            harness.runtimeContext,
          );
          await _waitForPayload(router);
        });

        expect(router.payloads, [
          TaskDataSynchronizationPayload.list(
            data: [TaskDeviceStatusSynchronization(data: historyDeviceStatus)],
          ),
        ]);
        expect(deviceStatusHistoryRepository.requestedBefore, now);

        await harness.dispose();
      },
    );

    test(
      'loads requested temporary target from history when cache is empty',
      () async {
        SharedPreferences.setMockInitialValues({});
        final now = DateTime(2026, 5, 18, 21, 30);
        final target = _temporaryTarget(
          id: 'target-1',
          createdAt: now.subtract(const Duration(minutes: 10)),
          duration: 30,
        );
        final router = RecordingTaskEventRouter();
        final container = ProviderContainer(
          overrides: [
            treatmentsHistoryRepositoryProvider.overrideWith(
              (_) async => _FakeTreatmentsHistoryRepository(target),
            ),
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);

        await withClock(Clock.fixed(now), () async {
          AppEventHandler().handle(
            const AppEvent.executeCommand(
              data: ExecuteCommandEvent.syncData(
                data: [SyncDataKey.temporaryTarget],
              ),
            ),
            harness.runtimeContext,
          );
          await _waitForPayload(router);
        });

        expect(router.payloads, [
          TaskDataSynchronizationPayload.list(
            data: [TaskTargetSynchronization(data: target)],
          ),
        ]);

        await harness.dispose();
      },
    );

    test('syncs local history after settings change', () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 5, 18, 21, 30);
      final historyDeviceStatus = testDeviceStatus(
        date: now.subtract(const Duration(minutes: 6)),
        iob: 0.6,
        cob: 12,
        tick: '+4',
        bg: 104,
      );
      final router = RecordingTaskEventRouter();
      final deviceStatusHistoryRepository = _FakeDeviceStatusHistoryRepository(
        historyDeviceStatus,
      );
      final container = ProviderContainer(
        overrides: [
          dataSourceConfigProvider.overrideWithValue(
            const AsyncData(
              DataSourceConfig(
                bgSource: BgSource.cloud,
                treatmentsSource: TreatmentsSource.cloud,
                pumpStatusSource: PumpStatusSource.cloud,
                historySource: HistorySource.local,
                mirrorToLocal: false,
              ),
            ),
          ),
          glucoseHistoryRepositoryProvider.overrideWith(
            (_) async => const _EmptyGlucoseHistoryRepository(),
          ),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (_) async => deviceStatusHistoryRepository,
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (_) async => const _EmptyTreatmentsHistoryRepository(),
          ),
          deviceStatusSourceRepositoryProvider.overrideWith(
            (_) async => const _ThrowingDeviceStatusSourceRepository(),
          ),
          taskEventRouterProvider.overrideWithValue(router),
        ],
      );
      final cacheController = container.read(
        synchronizationCacheControllerProvider,
      );
      final harness = FakeRuntimeHarness(container: container);

      await withClock(Clock.fixed(now), () async {
        AppEventHandler().handle(
          const AppEvent.executeCommand(
            data: ExecuteCommandEvent.syncSettings(data: {}),
          ),
          harness.runtimeContext,
        );
        await _waitForPayload(router);
      });

      expect(router.payloads, [
        TaskDataSynchronizationPayload.list(
          data: [TaskDeviceStatusSynchronization(data: historyDeviceStatus)],
        ),
      ]);
      expect(cacheController.getCache().glucoseReadingsCache, isEmpty);
      expect(cacheController.getCache().deviceStatusCache, historyDeviceStatus);

      await harness.dispose();
    });

    test(
      'syncs temporary target from history after clearing settings cache',
      () async {
        SharedPreferences.setMockInitialValues({});
        final now = DateTime(2026, 5, 18, 21, 30);
        final target = _temporaryTarget(
          id: 'target-1',
          createdAt: now.subtract(const Duration(minutes: 10)),
          duration: 30,
        );
        final router = RecordingTaskEventRouter();
        final container = ProviderContainer(
          overrides: [
            glucoseHistoryRepositoryProvider.overrideWith(
              (_) async => const _EmptyGlucoseHistoryRepository(),
            ),
            deviceStatusHistoryRepositoryProvider.overrideWith(
              (_) async => const _EmptyDeviceStatusHistoryRepository(),
            ),
            treatmentsHistoryRepositoryProvider.overrideWith(
              (_) async => _FakeTreatmentsHistoryRepository(target),
            ),
            deviceStatusSourceRepositoryProvider.overrideWith(
              (_) async => const _ThrowingDeviceStatusSourceRepository(),
            ),
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);

        await withClock(Clock.fixed(now), () async {
          AppEventHandler().handle(
            const AppEvent.executeCommand(
              data: ExecuteCommandEvent.syncSettings(data: {}),
            ),
            harness.runtimeContext,
          );
          await _waitForPayload(router);
        });

        expect(router.payloads, [
          TaskDataSynchronizationPayload.list(
            data: [TaskTargetSynchronization(data: target)],
          ),
        ]);
        expect(
          container
              .read(synchronizationCacheControllerProvider)
              .getCache()
              .targetCache,
          target,
        );

        await harness.dispose();
      },
    );
  });
}

Future<void> _waitForPayload(RecordingTaskEventRouter router) async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
    if (router.payloads.isNotEmpty) return;
  }
}

class RecordingTaskEventRouter extends TaskEventRouter {
  final List<TaskEventPayload> payloads = [];

  @override
  void send(TaskEventPayload payload) {
    payloads.add(payload);
  }
}

class _EmptyGlucoseHistoryRepository implements GlucoseHistoryRepository {
  const _EmptyGlucoseHistoryRepository();

  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    return Future.value(const []);
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) {
    return Future.value(const []);
  }
}

class _FakeGlucoseHistoryRepository implements GlucoseHistoryRepository {
  _FakeGlucoseHistoryRepository(this._readings);

  final List<Glucose> _readings;
  int? requestedRecentLimit;

  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    return Future.value(_readings);
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) {
    requestedRecentLimit = limit;
    return Future.value(_readings.take(limit).toList());
  }
}

class _EmptyDeviceStatusHistoryRepository
    implements DeviceStatusHistoryRepository {
  const _EmptyDeviceStatusHistoryRepository();

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) {
    return Future.value(const []);
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) {
    return Future.value(null);
  }
}

class _FakeDeviceStatusHistoryRepository
    implements DeviceStatusHistoryRepository {
  _FakeDeviceStatusHistoryRepository(this._deviceStatus);

  final DeviceStatus _deviceStatus;
  DateTime? requestedBefore;

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) {
    return Future.value([_deviceStatus]);
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) {
    requestedBefore = before;
    return Future.value(_deviceStatus);
  }
}

class _FakeTreatmentsHistoryRepository implements TreatmentsHistoryRepository {
  const _FakeTreatmentsHistoryRepository(this._target);

  final TemporaryTarget? _target;

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end) {
    throw StateError('temporary target cache should not fetch treatment lists');
  }

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() {
    return Future.value(_target);
  }
}

class _EmptyTreatmentsHistoryRepository implements TreatmentsHistoryRepository {
  const _EmptyTreatmentsHistoryRepository();

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end) {
    return Future.value(const []);
  }

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() {
    return Future.value(null);
  }
}

class _ThrowingDeviceStatusSourceRepository
    implements DeviceStatusSourceRepository {
  const _ThrowingDeviceStatusSourceRepository();

  @override
  Future<DeviceStatus> pollDeviceStatus() {
    throw StateError('Device status sync should use history, not polling');
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
