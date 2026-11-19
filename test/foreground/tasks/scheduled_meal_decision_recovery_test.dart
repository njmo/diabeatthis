import 'package:clock/clock.dart';
import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/common/meal_advisor/remote/scheduled_meal_decision_journal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/core/drift/mappers/meal_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/scheduled_caregiver_meal_decision.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/fake_runtime_harness.dart';

class _DecisionTransport implements AuthenticatedCallableTransport {
  int creates = 0;
  int fetches = 0;
  Map<String, dynamic>? request;

  @override
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, Object?> data, {
    String? expectedUid,
    Future<bool> Function()? allowRequest,
  }) async {
    expect(expectedUid, 'child');
    if (data['action'] == 'create') {
      expect(await allowRequest?.call(), isTrue);
      creates++;
      return request = {
        ...data,
        'status': 'open',
        'deadline': clock
            .now()
            .add(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      };
    }
    if (++fetches == 1) throw const CallableFailure('unavailable');
    return {
      'requests': [
        {...request!, 'id': request!['requestId'], 'status': 'expired'},
      ],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('waits for restored auth and retries a failed deadline check', () async {
    SharedPreferences.setMockInitialValues({
      mealDecisionPreferencesKey: const MealDecisionPreferences(
        method: MealDecisionMethod.caregiver,
      ).encode(),
    });
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    var now = DateTime(2026, 11, 19, 19, 35);
    final transport = _DecisionTransport();
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authenticatedFamilyTransportProvider.overrideWithValue(transport),
        scheduledMealDecisionUidProvider.overrideWithValue(
          () async => ++reads == 1 ? null : 'child',
        ),
      ],
    );
    addTearDown(container.dispose);
    final harness = FakeRuntimeHarness(container: container);

    Future<void> advanceToNextWait(Duration expectedDelay) async {
      for (var i = 0; i < 100 && harness.pendingDeadlines.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(harness.pendingDeadlines, contains(now.add(expectedDelay)));
      now = now.add(expectedDelay);
      harness.dispatchTick(now);
    }

    await withClock(Clock(() => now), () async {
      await db.customInsert(
        "INSERT INTO meal (id, name, planned_at, status) VALUES (1, 'Dinner', ?, 'planned')",
        variables: [
          Variable(now.add(const Duration(minutes: 3)).millisecondsSinceEpoch),
        ],
      );
      final meal = (await db.mealDao.getMealById(1))!.toDomain();
      final result = container.read(scheduledCaregiverMealDecisionProvider)(
        harness.runtimeContext,
        MealMonitorContext(activeMeal: meal),
        meal,
      );
      await advanceToNextWait(const Duration(seconds: 30));
      await advanceToNextWait(const Duration(minutes: 5));
      await advanceToNextWait(const Duration(seconds: 30));
      expect(await result, isFalse);
      expect(transport.creates, 1);
      expect(transport.fetches, 2);
    });
  });

  test('cleanup cancels stale meal and account notifications only', () async {
    final now = DateTime(2026, 11, 19, 19, 35);
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customInsert(
      "INSERT INTO meal (id, name, planned_at, status) VALUES "
      "(1, 'Kept', ?, 'planned'), (2, 'Moved', ?, 'planned'), "
      "(3, 'Skipped', ?, 'skipped'), (5, 'Untimed', NULL, 'planned')",
      variables: [
        Variable(now.millisecondsSinceEpoch),
        Variable(now.add(const Duration(hours: 1)).millisecondsSinceEpoch),
        Variable(now.millisecondsSinceEpoch),
      ],
    );
    final journal = ScheduledMealDecisionJournal(db);
    for (final id in [1, 2, 3, 4, 5]) {
      await journal.remember(id, now, uid: 'child', requestId: 'notice-$id');
    }
    final cancelled = <String>[];
    Future<void> cancel(String id) async => cancelled.add(id);
    await journal.cleanNotifications(uid: 'child', now: now, cancel: cancel);
    expect(
      cancelled,
      unorderedEquals(['notice-2', 'notice-3', 'notice-4', 'notice-5']),
    );
    expect(await journal.load(1, now), isNotNull);
    expect(await journal.load(5, now), isNull);
    cancelled.clear();

    await journal.cleanNotifications(
      uid: 'child',
      now: now,
      cancel: cancel,
      keepManualNotices: false,
    );
    expect(cancelled, isEmpty);
    await journal.complete(1, now, notified: true);
    await journal.cleanNotifications(
      uid: 'child',
      now: now,
      cancel: cancel,
      keepManualNotices: false,
    );
    expect(cancelled, ['notice-1']);
    expect((await journal.load(1, now))?.handled, isTrue);

    await journal.cleanNotifications(uid: null, now: now, cancel: cancel);
    expect(cancelled.last, 'notice-1');
    expect(await journal.load(1, now), isNull);
  });

  test(
    'an attempted request survives the planned time, a plain meal does not',
    () async {
      final now = DateTime(2026, 11, 19, 19, 35);
      final db = drift.DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await withClock(Clock.fixed(now), () async {
        final plannedAt = now.subtract(const Duration(minutes: 1));
        await db.customInsert(
          "INSERT INTO meal (id, name, planned_at, status) VALUES (1, 'Dinner', ?, 'planned')",
          variables: [Variable(plannedAt.millisecondsSinceEpoch)],
        );
        expect(await container.refresh(getNearestMealProvider.future), isNull);

        final journal = ScheduledMealDecisionJournal(db);
        await journal.remember(
          1,
          plannedAt,
          uid: 'child',
          requestId: 'existing',
        );
        final candidate = await container.refresh(
          getNearestMealProvider.future,
        );
        expect(candidate?.id, 1);

        await journal.complete(1, plannedAt);
        expect(await container.refresh(getNearestMealProvider.future), isNull);
      });
    },
  );
}
