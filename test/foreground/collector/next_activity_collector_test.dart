import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/collector/next_activity_collector.dart';
import 'package:diabeatthis/foreground/event/internal/activity_event.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  group('NextActivityCollector', () {
    test('emits next activity event for pending activity log', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      final startsAt = _truncateToMilliseconds(
        clock.now().add(const Duration(minutes: 30)),
      );
      await _seedPendingActivity(db, startsAt);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final harness = FakeRuntimeHarness(container: container);

      final collector = NextActivityCollector();
      addTearDown(collector.dispose);
      collector.start(
        CollectorContext.fromRuntimeContext(harness.runtimeContext),
      );
      await _flushMicrotasks();

      final events = harness.emittedEvents.whereType<NextActivityEvent>();

      expect(events, hasLength(1));
      expect(events.single.activityLogId, 1);
      expect(events.single.activityId, 1);
      expect(events.single.startsAt, startsAt);
    });

    test('emits next activity event for already active activity log', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final startsAt = _truncateToMilliseconds(
        clock.now().subtract(const Duration(minutes: 5)),
      );
      await _seedPendingActivity(db, startsAt);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final harness = FakeRuntimeHarness(container: container);

      final collector = NextActivityCollector();
      addTearDown(collector.dispose);
      collector.start(
        CollectorContext.fromRuntimeContext(harness.runtimeContext),
      );
      await _flushMicrotasks();

      final nextEvents = harness.emittedEvents.whereType<NextActivityEvent>();
      final startedEvents = harness.emittedEvents
          .whereType<ActivityStartedEvent>();

      expect(nextEvents, hasLength(1));
      expect(nextEvents.single.activityLogId, 1);
      expect(nextEvents.single.activityId, 1);
      expect(nextEvents.single.startsAt, startsAt);
      expect(startedEvents, hasLength(1));
      expect(startedEvents.single.activityLogId, 1);
      expect(startedEvents.single.activityId, 1);
      expect(startedEvents.single.startsAt, startsAt);
    });

    test(
      'emits activity cancelled event when planned activity is deleted',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);

        final startsAt = _truncateToMilliseconds(
          clock.now().add(const Duration(minutes: 30)),
        );
        await _seedPendingActivity(db, startsAt);

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final harness = FakeRuntimeHarness(container: container);

        final collector = NextActivityCollector();
        addTearDown(collector.dispose);
        collector.start(
          CollectorContext.fromRuntimeContext(harness.runtimeContext),
        );
        await _flushMicrotasks();

        await db.activityDao.removeActivityLog(
          ActivityLogCompanion(id: const Value<int>(1)),
        );
        await _flushMicrotasks();

        final cancelledEvents = harness.emittedEvents
            .whereType<ActivityCancelledEvent>();

        expect(cancelledEvents, hasLength(1));
        expect(cancelledEvents.single.activityLogId, 1);
        expect(cancelledEvents.single.activityId, 1);
        expect(cancelledEvents.single.startsAt, startsAt);
      },
    );

    test(
      'emits activity stopped event when active activity is ended',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);

        final startsAt = _truncateToMilliseconds(
          clock.now().subtract(const Duration(minutes: 5)),
        );
        final stoppedAt = _truncateToMilliseconds(clock.now());
        await _seedPendingActivity(db, startsAt);

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final harness = FakeRuntimeHarness(container: container);

        final collector = NextActivityCollector();
        addTearDown(collector.dispose);
        collector.start(
          CollectorContext.fromRuntimeContext(harness.runtimeContext),
        );
        await _flushMicrotasks();

        await db.activityDao.updateActivityLog(
          ActivityLogCompanion(
            id: const Value<int>(1),
            activityId: const Value<int>(1),
            startedAt: Value<int>(startsAt.millisecondsSinceEpoch),
            endedAt: Value<int>(stoppedAt.millisecondsSinceEpoch),
          ),
        );
        await _flushMicrotasks();

        final stoppedEvents = harness.emittedEvents
            .whereType<ActivityStoppedEvent>();

        expect(stoppedEvents, hasLength(1));
        expect(stoppedEvents.single.activityLogId, 1);
        expect(stoppedEvents.single.activityId, 1);
        expect(stoppedEvents.single.startsAt, startsAt);
        expect(stoppedEvents.single.stoppedAt, stoppedAt);
      },
    );
  });
}

Future<void> _seedPendingActivity(DatabaseImpl db, DateTime startsAt) async {
  await db.customInsert('''
    INSERT INTO activity (
      id,
      name,
      percentage_pre,
      percentage_post
    ) VALUES (1, 'Spacer', 10, 20)
    ''');
  await db.customInsert(
    '''
    INSERT INTO activity_log (
      id,
      activity_id,
      started_at
    ) VALUES (1, 1, ?)
    ''',
    variables: [Variable<int>(startsAt.millisecondsSinceEpoch)],
  );
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

DateTime _truncateToMilliseconds(DateTime value) {
  return DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);
}
