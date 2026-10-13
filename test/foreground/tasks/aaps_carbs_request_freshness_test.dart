import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_carbs_request_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/aaps_carbs_request_episode_store_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/aaps_carbs_request_episode_store.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/aaps_carbs_request_episode.dart';
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_event.dart';
import 'package:diabeatthis/foreground/event/internal/data_available_event.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:diabeatthis/foreground/task/tasks/aaps_carbs_request_monitor_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';
import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  final start = DateTime(2026, 10, 5, 12);
  for (final scenario in [
    'unchanged',
    'missing',
    'withdrawn',
    'changed',
    'expired_cgm',
    'restart',
    'incomplete_then_older',
  ]) {
    test('current AAPS suggestion: $scenario', () {
      fakeAsync((async) {
        withClock(Clock(() => start.add(async.elapsed)), () {
          final store = FreshnessEpisodeStore();
          final notifications = FakeNotificationsController();
          final container = ProviderContainer(
            overrides: [
              aapsCarbsRequestEpisodeStoreProvider.overrideWithValue(store),
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final cache = container
              .read(synchronizationCacheControllerProvider)
              .cache;
          final status = testDeviceStatus(
            date: start,
            iob: 0,
            cob: 0,
            tick: '0',
            bg: 100,
            carbsReq: 8,
          );
          if (scenario == 'restart') {
            store.value = store.value
                .acceptStatus(start, 8)
                .start('${start.microsecondsSinceEpoch}:remote')
                .reminded(start);
          } else {
            cache.cacheDeviceStatus(status);
            cache.cacheGlucose(
              Glucose(
                externalId: null,
                source: GlucoseSource.cloud,
                date: scenario == 'expired_cgm'
                    ? start.subtract(const Duration(minutes: 9))
                    : start,
                sgv: 100,
                direction: 'Flat',
              ),
            );
          }
          unawaited(
            const AapsCarbsRequestMonitorTask()
                .run(harness.runtimeContext)
                .catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                }),
          );
          async.flushMicrotasks();
          if (scenario == 'restart') {
            expect(notifications.shownEvents, isEmpty);
            expect(notifications.cancelledIds, isNotEmpty);
            expect(store.value.id, isNotNull);
          } else {
            expect(notifications.shownEvents, hasLength(1));
            if (scenario == 'unchanged') {
              async.elapse(const Duration(minutes: 5));
              harness.dispatchTick(start.add(async.elapsed));
              async.flushMicrotasks();
              expect(notifications.shownEvents, hasLength(1));
              expect(notifications.cancelledIds, isNotEmpty);
            } else if (scenario == 'expired_cgm') {
              async.elapse(const Duration(minutes: 1));
              harness.dispatchTick(start.add(async.elapsed));
              async.flushMicrotasks();
              expect(notifications.shownEvents, hasLength(1));
              expect(notifications.cancelledIds, isNotEmpty);
            } else {
              async.elapse(const Duration(minutes: 2));
              harness.dispatchTick(start.add(async.elapsed));
              final now = start.add(async.elapsed);
              if (scenario == 'withdrawn') {
                // A complete local calculation may omit carbsReq when no carbs are requested.
                cache.cacheDeviceStatus(
                  LocalDeviceStatusEvent.fromJson({
                    'created_at': now.toIso8601String(),
                    'openaps': {
                      'suggested': {
                        'timestamp': now.toIso8601String(),
                        'bg': 100,
                      },
                    },
                  }).data,
                );
              } else {
                cache.cacheDeviceStatus(
                  status.copyWith(
                    date: now,
                    carbsReq: scenario == 'changed' ? 4 : 8,
                    hasCarbsReq: scenario == 'changed',
                  ),
                );
              }
              harness.dispatchEvent(
                DataAvailableEvent(cache.deviceStatusCache),
              );
              async.flushMicrotasks();
              expect(notifications.cancelledIds, isNotEmpty);
              if (scenario == 'withdrawn') {
                expect(store.value.id, isNull);
              } else {
                expect(store.value.id, isNotNull);
              }
              if (scenario == 'incomplete_then_older') {
                cache.cacheDeviceStatus(
                  status.copyWith(
                    date: now.subtract(const Duration(seconds: 1)),
                  ),
                );
                harness.dispatchEvent(
                  DataAvailableEvent(cache.deviceStatusCache),
                );
                async.flushMicrotasks();
              }
              async.elapse(const Duration(minutes: 3));
              harness.dispatchTick(start.add(async.elapsed));
              async.flushMicrotasks();
              if (scenario == 'changed') {
                expect(notifications.shownEvents, hasLength(2));
                expect(
                  (notifications.shownEvents.last
                          as AapsCarbsRequestNotificationEvent)
                      .carbs,
                  4,
                );
              } else {
                expect(notifications.shownEvents, hasLength(1));
              }
            }
          }
          harness.cancel();
          async.flushMicrotasks();
          container.dispose();
        });
      });
    });
  }
}

class FreshnessEpisodeStore implements AapsCarbsRequestEpisodeStore {
  AapsCarbsRequestEpisode value = const AapsCarbsRequestEpisode.empty();
  @override
  Future<AapsCarbsRequestEpisode> load() async => value;
  @override
  Future<void> start(String id) async {
    value = value.start(id);
  }

  @override
  Future<void> markReminded(DateTime at) async {
    value = value.reminded(at);
  }

  @override
  Future<void> acceptStatus(DateTime at, double? carbs) async {
    value = value.acceptStatus(at, carbs);
  }

  @override
  Future<void> acknowledge(String id) async {
    value = value.acknowledge(id);
  }

  @override
  Future<void> clear() async {
    value = value.clear();
  }

  @override
  Future<void> markNotificationCancelled() async {
    value = value.cancelled();
  }
}
