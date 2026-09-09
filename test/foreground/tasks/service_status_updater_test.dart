import 'dart:async';

import 'package:diabeatthis/common/monitoring/activity_monitoring_phase.dart';
import 'package:diabeatthis/common/monitoring/activity_monitoring_status.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_status.dart';
import 'package:diabeatthis/common/monitoring/monitoring_notification_content.dart';
import 'package:diabeatthis/core/logger/logger.dart';
import 'package:diabeatthis/foreground/event/internal/monitoring_status_changed.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/runtime/workflow_scheduler.dart';
import 'package:diabeatthis/foreground/task/tasks/service_status_updater_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/controlled_meal_monitor.dart';

const mealEvent = MealMonitoringStatusChanged(
  MealMonitoringStatus(
    phase: MealMonitoringPhase.waitingForBolus,
    mealId: 1,
    name: 'Obiad',
  ),
);
const activityEvent = ActivityMonitoringStatusChanged(
  ActivityMonitoringStatus(
    phase: ActivityMonitoringPhase.active,
    activityLogId: 2,
    name: 'Spacer',
  ),
);
const idleMeal = MealMonitoringStatusChanged(
  MealMonitoringStatus(phase: MealMonitoringPhase.idle),
);
const idleActivity = ActivityMonitoringStatusChanged(
  ActivityMonitoringStatus(phase: ActivityMonitoringPhase.idle),
);

void main() {
  LogRuntimeConfig.configure(isUnitTest: true, enableBuffer: false);

  test('combines same-flush events and queues changes during a slow write', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final scheduler = WorkflowScheduler();
      final writes = <MonitoringNotificationContent>[];
      final slowWrite = Completer<void>();
      scheduler.startTask(
        ServiceStatusUpdaterTask(
          writer: (content) async {
            writes.add(content);
            if (writes.length == 2) await slowWrite.future;
          },
        ),
        scheduler.createContext(container),
      );
      scheduler.emitEvent(mealEvent);
      scheduler.emitEvent(activityEvent);
      async.flushMicrotasks();
      expect(writes, hasLength(2));
      expect(writes.last.title, 'Monitorowanie posiłku i aktywności');
      expect(writes.last.text, contains('Obiad'));
      expect(writes.last.text, contains('Spacer'));

      scheduler.emitEvent(idleMeal);
      scheduler.emitEvent(idleActivity);
      async.flushMicrotasks();
      expect(writes, hasLength(2));
      slowWrite.complete();
      async.flushMicrotasks();
      expect(writes, hasLength(3));
      expect(writes.last.text, 'Brak bieżących zdarzeń');
      scheduler.emitEvent(idleActivity);
      async.flushMicrotasks();
      expect(writes, hasLength(3));
      unawaited(scheduler.dispose());
      async.flushMicrotasks();
      container.dispose();
    });
  });

  test('retries the latest state without external scheduler ticks', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final scheduler = WorkflowScheduler();
      final writes = <MonitoringNotificationContent>[];
      scheduler.startTask(
        ServiceStatusUpdaterTask(
          writer: (content) async {
            writes.add(content);
            if (writes.length == 1) throw StateError('Unavailable');
          },
        ),
        scheduler.createContext(container),
      );
      async.flushMicrotasks();
      scheduler.emitEvent(mealEvent);
      scheduler.emitEvent(activityEvent);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      expect(writes, hasLength(2));
      expect(writes.last.title, 'Monitorowanie posiłku i aktywności');
      unawaited(scheduler.dispose());
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
      container.dispose();
    });
  });

  test('shutdown cancels a blocked writer without starting another update', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final scheduler = WorkflowScheduler();
      final blocked = Completer<void>();
      var writes = 0;
      scheduler.startTask(
        ServiceStatusUpdaterTask(
          writer: (_) {
            writes++;
            return blocked.future;
          },
        ),
        scheduler.createContext(container),
      );
      scheduler.emitEvent(mealEvent);
      async.flushMicrotasks();
      var disposed = false;
      unawaited(scheduler.dispose().then((_) => disposed = true));
      async.flushMicrotasks();
      expect(disposed, isTrue);
      expect(writes, 1);
      // A late platform error must be observed without retrying after shutdown.
      blocked.completeError(StateError('Late platform failure'));
      async.flushMicrotasks();
      expect(writes, 1);
      expect(async.pendingTimers, isEmpty);
      container.dispose();
    });
  });

  for (final failure in [false, true]) {
    test(
      'unexpected monitor termination reports unavailable (failure: $failure)',
      () {
        fakeAsync((async) {
          final container = ProviderContainer();
          final scheduler = WorkflowScheduler();
          final completion = Completer<void>();
          final writes = <MonitoringNotificationContent>[];
          scheduler.startTask(
            ServiceStatusUpdaterTask(
              writer: (content) async {
                writes.add(content);
              },
            ),
            scheduler.createContext(container),
          );
          scheduler.startTask(
            ControlledMealMonitor((context) async {
              context.emitEvent(mealEvent);
              await completion.future;
              if (failure) throw StateError('Repository failed');
            }),
            scheduler.createContext(container),
          );
          scheduler.emitEvent(activityEvent);
          async.flushMicrotasks();
          expect(writes.last.title, 'Monitorowanie posiłku i aktywności');
          completion.complete();
          async.flushMicrotasks();
          expect(writes.last.title, 'Problem z monitorowaniem');
          expect(
            writes.last.text,
            contains('Posiłek · monitorowanie niedostępne'),
          );
          expect(writes.last.text, contains('Spacer'));
          expect(writes.last.text, isNot(contains('oczekiwanie na bolus')));
          unawaited(scheduler.dispose());
          async.flushMicrotasks();
          container.dispose();
        });
      },
    );
  }

  test('synchronous monitor failure is also reported', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final scheduler = WorkflowScheduler();
      final writes = <MonitoringNotificationContent>[];
      scheduler.startTask(
        ServiceStatusUpdaterTask(
          writer: (content) async {
            writes.add(content);
          },
        ),
        scheduler.createContext(container),
      );
      scheduler.startTask(
        ControlledMealMonitor((_) => throw StateError('Initialization failed')),
        scheduler.createContext(container),
      );
      async.flushMicrotasks();
      expect(writes.last.title, 'Problem z monitorowaniem');
      unawaited(scheduler.dispose());
      async.flushMicrotasks();
      container.dispose();
    });
  });

  test('disposal cancels a pending retry', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final scheduler = WorkflowScheduler();
      var attempts = 0;
      scheduler.startTask(
        ServiceStatusUpdaterTask(
          writer: (_) async {
            attempts++;
            throw StateError('Unavailable');
          },
        ),
        scheduler.createContext(container),
      );
      async.flushMicrotasks();
      unawaited(scheduler.dispose());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      expect(attempts, 1);
      expect(async.pendingTimers, isEmpty);
      container.dispose();
    });
  });

  test(
    'inboxes buffer independently and coexist with one-shot waiters',
    () async {
      final container = ProviderContainer();
      final scheduler = WorkflowScheduler();
      final context = scheduler.createContext(container);
      final inbox = context.openEventInbox<MonitoringStatusChanged>();
      final mealInbox = context.openEventInbox<MealMonitoringStatusChanged>();
      final waiter = context.waitForEvent<MealMonitoringStatusChanged>();
      scheduler.emitEvent(mealEvent);
      scheduler.emitEvent(activityEvent);
      expect(await waiter, same(mealEvent));
      expect(await inbox.nextBatch(), [mealEvent, activityEvent]);
      expect(await mealInbox.nextBatch(), [mealEvent]);
      final pending = inbox.nextBatch();
      final cancelled = expectLater(
        pending,
        throwsA(isA<TaskCancelledException>()),
      );
      await scheduler.dispose();
      await cancelled;
      container.dispose();
    },
  );

  test('task cancellation closes its inbox', () async {
    final container = ProviderContainer();
    final scheduler = WorkflowScheduler();
    final context = scheduler.createContext(container);
    final inbox = context.openEventInbox<MonitoringStatusChanged>();
    final cancelled = expectLater(
      inbox.nextBatch(),
      throwsA(isA<TaskCancelledException>()),
    );
    context.cancellation.cancel();
    await cancelled;
    await scheduler.dispose();
    container.dispose();
  });
}
