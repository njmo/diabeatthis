import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/aaps_carbs_request_episode_store_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/aaps_carbs_request_episode_store.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/aaps_carbs_request_episode.dart';
import 'package:diabeatthis/foreground/event/internal/aaps_carbs_request_acknowledged_event.dart';
import 'package:diabeatthis/foreground/event/internal/data_available_event.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:diabeatthis/foreground/task/tasks/aaps_carbs_request_monitor_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';
import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  final start = DateTime(2026, 9, 15, 12);

  test(
    'hides without replaying the saved request when the cache regresses',
    () {
      fakeAsync((async) {
        withClock(Clock(() => start.add(async.elapsed)), () {
          final fixture = _fixture(start);
          unawaited(
            const AapsCarbsRequestMonitorTask()
                .run(fixture.harness.runtimeContext)
                .catchError((_) {}),
          );
          async.flushMicrotasks();
          expect(fixture.notifications.shownEvents, hasLength(1));

          fixture.cache.cacheDeviceStatus(
            testDeviceStatus(
              date: start.subtract(const Duration(minutes: 2)),
              iob: 0,
              cob: 0,
              tick: '0',
              bg: 100,
            ),
          );
          async.elapse(const Duration(minutes: 5, seconds: 1));
          fixture.harness.dispatchEvent(
            DataAvailableEvent(fixture.cache.deviceStatusCache),
          );
          fixture.harness.dispatchTick(start.add(async.elapsed));
          async.flushMicrotasks();

          expect(fixture.notifications.shownEvents, hasLength(1));
          expect(fixture.notifications.cancelledIds, isNotEmpty);
          expect(fixture.store.value.id, isNotNull);
          fixture.harness.cancel();
        });
      });
    },
  );

  test('fresh withdrawal cancels and a new request starts a new episode', () {
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        final fixture = _fixture(start);
        unawaited(
          const AapsCarbsRequestMonitorTask()
              .run(fixture.harness.runtimeContext)
              .catchError((_) {}),
        );
        async.flushMicrotasks();
        final firstId = fixture.store.value.id;
        fixture.cache.cacheDeviceStatus(
          testDeviceStatus(
            date: start,
            iob: 0,
            cob: 0,
            tick: '0',
            bg: 100,
            carbsReq: 0,
          ),
        );
        fixture.harness.dispatchEvent(
          DataAvailableEvent(fixture.cache.deviceStatusCache),
        );
        fixture.harness.dispatchTick(start.add(async.elapsed));
        async.flushMicrotasks();
        expect(fixture.store.value.id, isNull);
        expect(fixture.notifications.cancelledIds, hasLength(1));
        async.elapse(const Duration(minutes: 1));
        fixture.cache.cacheDeviceStatus(
          testDeviceStatus(
            date: start.add(async.elapsed),
            iob: 0,
            cob: 0,
            tick: '0',
            bg: 100,
            carbsReq: 8,
          ),
        );
        fixture.harness.dispatchEvent(
          DataAvailableEvent(fixture.cache.deviceStatusCache),
        );
        fixture.harness.dispatchTick(start.add(async.elapsed));
        async.flushMicrotasks();
        expect(fixture.notifications.shownEvents, hasLength(2));
        expect(fixture.store.value.id, isNot(firstId));
        fixture.harness.cancel();
      });
    });
  });

  test(
    'fresh data after a stale interval does not rearm an acknowledged request',
    () {
      fakeAsync((async) {
        withClock(Clock(() => start.add(async.elapsed)), () {
          final fixture = _fixture(start);
          unawaited(
            const AapsCarbsRequestMonitorTask()
                .run(fixture.harness.runtimeContext)
                .catchError((_) {}),
          );
          async.flushMicrotasks();
          final firstId = fixture.store.value.id;
          fixture.harness.dispatchEvent(
            AapsCarbsRequestAcknowledgedEvent(episodeId: firstId),
          );
          async.flushMicrotasks();
          async.elapse(const Duration(minutes: 15));
          fixture.harness.dispatchEvent(
            DataAvailableEvent(fixture.cache.deviceStatusCache),
          );
          fixture.harness.dispatchTick(start.add(async.elapsed));
          async.flushMicrotasks();
          fixture.cache.cacheDeviceStatus(
            testDeviceStatus(
              date: start.add(async.elapsed),
              iob: 0,
              cob: 0,
              tick: '0',
              bg: 100,
              carbsReq: 8,
            ),
          );
          fixture.cache.cacheGlucose(
            Glucose(
              externalId: null,
              source: GlucoseSource.cloud,
              date: start.add(async.elapsed),
              sgv: 100,
              direction: 'Flat',
            ),
          );
          fixture.harness.dispatchEvent(
            DataAvailableEvent(fixture.cache.deviceStatusCache),
          );
          fixture.harness.dispatchTick(start.add(async.elapsed));
          async.flushMicrotasks();
          expect(fixture.notifications.shownEvents, hasLength(1));
          expect(fixture.store.value.id, firstId);
          expect(fixture.store.value.acknowledged, true);
          fixture.harness.cancel();
        });
      });
    },
  );

  test('valid form acknowledgement survives an older cache entry', () {
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        final fixture = _fixture(start);
        unawaited(
          const AapsCarbsRequestMonitorTask()
              .run(fixture.harness.runtimeContext)
              .catchError((_) {}),
        );
        async.flushMicrotasks();
        final acceptedAt = fixture.store.value.lastAcceptedStatusAt!;
        fixture.cache.cacheDeviceStatus(
          testDeviceStatus(
            date: acceptedAt.subtract(const Duration(minutes: 1)),
            iob: 0,
            cob: 0,
            tick: '0',
            bg: 100,
          ),
        );
        fixture.harness.dispatchEvent(
          AapsCarbsRequestAcknowledgedEvent(suggestionAt: acceptedAt),
        );
        async.flushMicrotasks();
        expect(fixture.store.value.acknowledged, true);
        expect(fixture.notifications.cancelledIds, hasLength(1));
        fixture.harness.cancel();
      });
    });
  });

  test('retains acknowledgement until persistence succeeds', () {
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        final fixture = _fixture(start);
        unawaited(
          const AapsCarbsRequestMonitorTask()
              .run(fixture.harness.runtimeContext)
              .catchError((_) {}),
        );
        async.flushMicrotasks();
        fixture.store.acknowledgementFailures = 1;
        fixture.harness.dispatchEvent(
          AapsCarbsRequestAcknowledgedEvent(episodeId: fixture.store.value.id),
        );
        async.flushMicrotasks();
        expect(fixture.store.value.acknowledged, false);
        async.elapse(AapsCarbsRequestMonitorTask.failureRetryInterval);
        fixture.harness.dispatchTick(start.add(async.elapsed));
        async.flushMicrotasks();
        expect(fixture.store.value.acknowledged, true);
        expect(fixture.notifications.cancelledIds, hasLength(1));
        expect(fixture.notifications.shownEvents, hasLength(1));
        fixture.harness.cancel();
      });
    });
  });

  test('old form timestamp does not acknowledge the current episode', () {
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        final fixture = _fixture(start);
        unawaited(
          const AapsCarbsRequestMonitorTask()
              .run(fixture.harness.runtimeContext)
              .catchError((_) {}),
        );
        async.flushMicrotasks();

        fixture.harness.dispatchEvent(
          AapsCarbsRequestAcknowledgedEvent(
            suggestionAt: start.subtract(const Duration(minutes: 2)),
          ),
        );
        async.flushMicrotasks();

        expect(fixture.store.value.acknowledged, false);
        fixture.harness.cancel();
      });
    });
  });

  test('recovers after one notification writer failure', () {
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        final fixture = _fixture(start);
        fixture.notifications.enqueueShowError(StateError('temporary'));
        unawaited(
          const AapsCarbsRequestMonitorTask()
              .run(fixture.harness.runtimeContext)
              .catchError((_) {}),
        );
        async.flushMicrotasks();
        expect(fixture.harness.activeWaitersCount, 1);
        async.elapse(AapsCarbsRequestMonitorTask.failureRetryInterval);
        fixture.harness.dispatchEvent(
          DataAvailableEvent(fixture.cache.deviceStatusCache),
        );
        fixture.harness.dispatchTick(start.add(async.elapsed));
        async.flushMicrotasks();

        expect(fixture.notifications.shownEvents, hasLength(2));
        expect(fixture.harness.activeWaitersCount, 2);
        fixture.harness.cancel();
      });
    });
  });

  test('retries notification cancellation after acknowledgement', () {
    fakeAsync((async) {
      withClock(Clock(() => start.add(async.elapsed)), () {
        final fixture = _fixture(start);
        fixture.notifications.enqueueCancelError(StateError('temporary'));
        fixture.notifications.enqueueCancelError(
          StateError('still unavailable'),
        );
        fixture.notifications.enqueueCancelSuccess();
        unawaited(
          const AapsCarbsRequestMonitorTask()
              .run(fixture.harness.runtimeContext)
              .catchError((_) {}),
        );
        async.flushMicrotasks();

        fixture.harness.dispatchEvent(
          AapsCarbsRequestAcknowledgedEvent(episodeId: fixture.store.value.id),
        );
        async.flushMicrotasks();
        for (var attempt = 0; attempt < 2; attempt++) {
          async.elapse(AapsCarbsRequestMonitorTask.failureRetryInterval);
          fixture.harness.dispatchTick(start.add(async.elapsed));
          async.flushMicrotasks();
        }

        expect(fixture.notifications.cancelledIds, hasLength(3));
        expect(fixture.store.value.acknowledged, true);
        expect(fixture.store.value.notificationCancellationPending, false);
        fixture.harness.cancel();
      });
    });
  });
}

({
  FakeRuntimeHarness harness,
  FakeNotificationsController notifications,
  _MemoryStore store,
  SynchronizationCache cache,
})
_fixture(DateTime now) {
  final notifications = FakeNotificationsController();
  final store = _MemoryStore();
  final container = ProviderContainer(
    overrides: [
      notificationsControllerForegroundProvider.overrideWithValue(
        notifications,
      ),
      aapsCarbsRequestEpisodeStoreProvider.overrideWithValue(store),
    ],
  );
  final cache = container.read(synchronizationCacheControllerProvider).cache;
  cache.cacheDeviceStatus(
    testDeviceStatus(
      date: now.subtract(const Duration(minutes: 1)),
      iob: 0,
      cob: 0,
      tick: '0',
      bg: 100,
      carbsReq: 8,
    ),
  );
  cache.cacheGlucose(
    Glucose(
      externalId: null,
      source: GlucoseSource.cloud,
      date: now.subtract(const Duration(minutes: 1)),
      sgv: 100,
      direction: 'Flat',
    ),
  );
  return (
    harness: FakeRuntimeHarness(container: container),
    notifications: notifications,
    store: store,
    cache: cache,
  );
}

class _MemoryStore implements AapsCarbsRequestEpisodeStore {
  int acknowledgementFailures = 0;
  AapsCarbsRequestEpisode value = const AapsCarbsRequestEpisode.empty();

  @override
  Future<AapsCarbsRequestEpisode> load() async => value;

  @override
  Future<void> acceptStatus(DateTime at, double? activeCarbsReq) async {
    value = AapsCarbsRequestEpisode(
      id: value.id,
      acknowledged: value.acknowledged,
      lastReminderAt: value.lastReminderAt,
      lastAcceptedStatusAt: at,
      activeCarbsReq: activeCarbsReq,
      notificationCancellationPending: value.notificationCancellationPending,
    );
  }

  @override
  Future<void> start(String episodeId) async {
    value = AapsCarbsRequestEpisode(
      id: episodeId,
      acknowledged: false,
      lastReminderAt: null,
      lastAcceptedStatusAt: value.lastAcceptedStatusAt,
      activeCarbsReq: value.activeCarbsReq,
      notificationCancellationPending: value.notificationCancellationPending,
    );
  }

  @override
  Future<void> markReminded(DateTime at) async {
    value = AapsCarbsRequestEpisode(
      id: value.id,
      acknowledged: value.acknowledged,
      lastReminderAt: at,
      lastAcceptedStatusAt: value.lastAcceptedStatusAt,
      activeCarbsReq: value.activeCarbsReq,
      notificationCancellationPending: value.notificationCancellationPending,
    );
  }

  @override
  Future<void> acknowledge(String episodeId) async {
    if (acknowledgementFailures > 0) {
      acknowledgementFailures--;
      throw StateError('Persistence unavailable');
    }
    if (value.id != episodeId) return;
    value = AapsCarbsRequestEpisode(
      id: value.id,
      acknowledged: true,
      lastReminderAt: value.lastReminderAt,
      lastAcceptedStatusAt: value.lastAcceptedStatusAt,
      activeCarbsReq: value.activeCarbsReq,
      notificationCancellationPending: true,
    );
  }

  @override
  Future<void> clear() async {
    value = AapsCarbsRequestEpisode(
      id: null,
      acknowledged: false,
      lastReminderAt: null,
      lastAcceptedStatusAt: value.lastAcceptedStatusAt,
      activeCarbsReq: null,
      notificationCancellationPending: true,
    );
  }

  @override
  Future<void> markNotificationCancelled() async {
    value = AapsCarbsRequestEpisode(
      id: value.id,
      acknowledged: value.acknowledged,
      lastReminderAt: value.lastReminderAt,
      lastAcceptedStatusAt: value.lastAcceptedStatusAt,
      activeCarbsReq: value.activeCarbsReq,
      notificationCancellationPending: false,
    );
  }
}
