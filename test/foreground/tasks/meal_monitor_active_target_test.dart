import 'package:clock/clock.dart';
import 'package:diabeatthis/common/monitoring/is_temporary_target_active.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/monitor_until_meal.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

TemporaryTarget temporaryTarget(DateTime createdAt) => TemporaryTarget(
  nightscoutId: null,
  createdAt: createdAt,
  durationInMiliseconds: 3600000,
  duration: 60,
  targetBottom: 90,
  targetTop: 100,
);

void main() {
  test(
    'ignores expired target events and stops retries after an active target',
    () {
      fakeAsync((async) {
        final start = DateTime(2026, 9, 10, 12);
        withClock(Clock(() => start.add(async.elapsed)), () {
          final notifications = FakeNotificationsController();
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          bool? detected;
          MonitorUntilMeal()
              .showTempTargetUntilDetected(
                harness.runtimeContext,
                1,
                const Duration(minutes: 15),
              )
              .then((value) => detected = value);
          async.flushMicrotasks();
          expect(notifications.shownEvents, hasLength(1));

          harness.dispatchEvent(
            TreatmentAvailableEvent<TemporaryTarget>(
              temporaryTarget(clock.now().subtract(const Duration(hours: 1))),
            ),
          );
          async.flushMicrotasks();
          expect(detected, isNull);

          async.elapse(const Duration(minutes: 5));
          harness.dispatchTick(clock.now());
          async.flushMicrotasks();
          expect(notifications.shownEvents, hasLength(2));

          harness.dispatchEvent(
            TreatmentAvailableEvent<TemporaryTarget>(
              temporaryTarget(clock.now()),
            ),
          );
          async.flushMicrotasks();
          expect(detected, isTrue);

          async.elapse(const Duration(minutes: 5));
          harness.dispatchTick(clock.now());
          async.flushMicrotasks();
          expect(notifications.shownEvents, hasLength(2));
          container.dispose();
        });
      });
    },
  );

  test(
    'only valid targets within their active interval suppress reminders',
    () {
      final now = DateTime(2026, 9, 10, 12);
      withClock(Clock.fixed(now), () {
        final target = temporaryTarget(now);
        expect(isTemporaryTargetActive(target), isTrue);
        expect(isTemporaryTargetActive(null), isFalse);
        expect(
          isTemporaryTargetActive(target.copyWith(isValid: false)),
          isFalse,
        );
        expect(isTemporaryTargetActive(target.copyWith(duration: 0)), isFalse);
        expect(
          isTemporaryTargetActive(
            temporaryTarget(now.subtract(const Duration(hours: 1))),
          ),
          isFalse,
        );
        expect(
          isTemporaryTargetActive(
            temporaryTarget(now.add(const Duration(minutes: 1))),
          ),
          isFalse,
        );
      });
    },
  );

  for (final initiallyActive in [true, false]) {
    test(
      'checks cached target ${initiallyActive ? 'before first reminder' : 'before retry without a new event'}',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 9, 10, 12);
          withClock(Clock(() => start.add(async.elapsed)), () {
            final notifications = FakeNotificationsController();
            final container = ProviderContainer(
              overrides: [
                notificationsControllerForegroundProvider.overrideWithValue(
                  notifications,
                ),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final cache = container.read(
              synchronizationCacheControllerProvider,
            );
            if (initiallyActive) {
              cache.cacheTarget(temporaryTarget(clock.now()));
            }
            bool? detected;
            MonitorUntilMeal()
                .showTempTargetUntilDetected(
                  harness.runtimeContext,
                  1,
                  const Duration(minutes: 15),
                )
                .then((value) => detected = value);
            async.flushMicrotasks();
            expect(notifications.shownEvents.length, initiallyActive ? 0 : 1);

            if (!initiallyActive) {
              cache.cacheTarget(temporaryTarget(clock.now()));
              async.elapse(const Duration(minutes: 5));
              harness.dispatchTick(clock.now());
              async.flushMicrotasks();
            }
            expect(detected, isTrue);
            expect(notifications.shownEvents.length, initiallyActive ? 0 : 1);
            container.dispose();
          });
        });
      },
    );
  }
}
