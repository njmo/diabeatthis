import 'dart:async';
import 'dart:convert';

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
import 'package:diabeatthis/foreground/collector/next_meal_collector.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/scheduled_caregiver_meal_decision.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/fake_runtime_harness.dart';

class _OpenRequestTransport implements AuthenticatedCallableTransport {
  _OpenRequestTransport(this.db, this.deadline);
  final drift.DatabaseImpl db;
  final DateTime deadline;
  Completer<void>? holdFetch;
  bool fetchStarted = false;
  @override
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, Object?> data, {
    String? expectedUid,
    Future<bool> Function()? allowRequest,
  }) async {
    fetchStarted = true;
    await holdFetch?.future;
    final row = await db
        .customSelect(
          'SELECT source_id FROM family_sync_identity WHERE singleton=1',
        )
        .getSingle();
    return {
      'requests': [
        {
          'id': 'request',
          'sourceId': row.read<String>('source_id'),
          'status': 'open',
          'deadline': deadline.millisecondsSinceEpoch,
        },
      ],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({
      drift.DatabaseImpl db,
      ProviderContainer container,
      FakeRuntimeHarness harness,
    })
  >
  setup(DateTime plannedAt, {bool scheduled = true, int? boundAt}) async {
    SharedPreferences.setMockInitialValues({
      mealDecisionPreferencesKey: const MealDecisionPreferences(
        method: MealDecisionMethod.caregiver,
      ).encode(),
    });
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        scheduledMealDecisionUidProvider.overrideWithValue(() async => 'child'),
      ],
    );
    final harness = FakeRuntimeHarness(container: container);
    addTearDown(() async {
      harness.cancellation.cancel();
      container.dispose();
      await db.close();
    });
    await db.customInsert(
      "INSERT INTO meal (id,name,planned_at,status) VALUES (1,'Dinner',?,'planned')",
      variables: [Variable(plannedAt.millisecondsSinceEpoch)],
    );
    await db.customInsert(
      "INSERT INTO meal_advisor_result (meal_id,result,initial_wait_time,final_wait_time,wait_time_ignored,advice_source,caregiver_uid,caregiver_request_id) VALUES (1,'bolused-waiting',10,10,0,'caregiver','caregiver','request')",
    );
    await db.customInsert(
      'INSERT INTO family_meal_decision_receipts (request_id,owner_uid,source_id,meal_id,acceptance_token,outcome_json,created_at) VALUES (?,?,?,?,?,?,?)',
      variables: [
        const Variable('request'),
        const Variable('child'),
        const Variable('source'),
        const Variable(1),
        const Variable('token'),
        Variable(
          jsonEncode({
            'source': 'caregiver',
            'decision': 'insulinThenWait',
            'minutes': 10,
            'caregiverUid': 'caregiver',
            'scheduled': scheduled,
            'plannedAt': boundAt ?? plannedAt.millisecondsSinceEpoch,
          }),
        ),
        Variable(
          plannedAt
              .subtract(const Duration(minutes: 20))
              .millisecondsSinceEpoch,
        ),
      ],
    );
    final journal = ScheduledMealDecisionJournal(db);
    await journal.remember(1, plannedAt, uid: 'child', requestId: 'request');
    await journal.complete(1, plannedAt);
    return (db: db, container: container, harness: harness);
  }

  test(
    'accepted prebolus due now starts waiting for delivery, only once after restart',
    () async {
      final plannedAt = DateTime(2026, 11, 22, 12);
      final now = plannedAt.subtract(const Duration(minutes: 10));
      final state = await setup(plannedAt);
      await withClock(Clock.fixed(now), () async {
        final meal = (await state.db.mealDao.getMealById(1))!.toDomain();
        await state.container.read(scheduledCaregiverMealDecisionProvider)(
          state.harness.runtimeContext,
          MealMonitorContext(activeMeal: meal),
          meal,
        );
        expect(
          (await state.db.mealDao.getMealById(1))!.status,
          'waiting-for-bolus',
        );
        final history = await state.db.mealAdvisorResultDao
            .getMealStatusHistory(1);
        expect(
          history.where((status) => status == 'waiting-for-bolus'),
          hasLength(1),
        );
      });
    },
  );

  for (final holdFetch in [false, true]) {
    test(
      'acceptance schedules exactly at prebolus with a pending ${holdFetch ? "fetch" : "deadline"}',
      () async {
        final plannedAt = DateTime(2026, 11, 22, 12);
        var now = plannedAt.subtract(const Duration(minutes: 19, seconds: 30));
        final state = await setup(plannedAt);
        await state.db.customStatement(
          'UPDATE scheduled_meal_decision SET handled=0',
        );
        await state.db.customStatement(
          'DELETE FROM family_meal_decision_receipts',
        );
        await state.db.customStatement(
          'UPDATE meal_advisor_result SET initial_wait_time=19, final_wait_time=19',
        );
        final transport = _OpenRequestTransport(state.db, plannedAt);
        if (holdFetch) {
          transport.holdFetch = Completer<void>();
          addTearDown(() => transport.holdFetch!.complete());
        }
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(state.db),
            scheduledMealDecisionUidProvider.overrideWithValue(
              () async => 'child',
            ),
            authenticatedFamilyTransportProvider.overrideWithValue(transport),
          ],
        );
        addTearDown(container.dispose);
        final harness = FakeRuntimeHarness(container: container);
        addTearDown(harness.dispose);
        await withClock(Clock(() => now), () async {
          final collector = NextMealCollector();
          collector.start(
            CollectorContext.fromRuntimeContext(harness.runtimeContext),
          );
          addTearDown(collector.dispose);
          final meal = (await state.db.mealDao.getMealById(1))!.toDomain();
          final running = container.read(
            scheduledCaregiverMealDecisionProvider,
          )(harness.runtimeContext, MealMonitorContext(activeMeal: meal), meal);
          running.ignore();
          for (
            var i = 0;
            i < 200 &&
                !(holdFetch
                    ? transport.fetchStarted
                    : harness.pendingDeadlines.contains(plannedAt));
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          if (holdFetch) {
            expect(transport.fetchStarted, isTrue);
          } else {
            expect(harness.pendingDeadlines, contains(plannedAt));
          }
          await state.db.customInsert(
            'INSERT INTO family_meal_decision_receipts(request_id,owner_uid,source_id,meal_id,acceptance_token,outcome_json,created_at) VALUES(?,?,?,?,?,?,?)',
            variables: [
              const Variable('request'),
              const Variable('child'),
              const Variable('source'),
              const Variable(1),
              const Variable('token'),
              Variable(
                jsonEncode({
                  'source': 'caregiver',
                  'decision': 'insulinThenWait',
                  'minutes': 19,
                  'caregiverUid': 'caregiver',
                  'scheduled': true,
                  'plannedAt': plannedAt.millisecondsSinceEpoch,
                }),
              ),
              Variable(now.millisecondsSinceEpoch),
            ],
            updates: {state.db.familyMealDecisionReceipts},
          );
          final due = plannedAt.subtract(const Duration(minutes: 19));
          for (
            var i = 0;
            i < 200 && !harness.pendingDeadlines.contains(due);
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(harness.pendingDeadlines, contains(due));
          expect((await state.db.mealDao.getMealById(1))!.status, 'planned');
          now = due;
          harness.dispatchTick(now);
          await running;
          expect(
            (await state.db.mealDao.getMealById(1))!.status,
            'waiting-for-bolus',
          );
        });
      },
    );
  }

  test('an accepted decision waits until the selected prebolus time', () async {
    final plannedAt = DateTime(2026, 11, 22, 12);
    var now = plannedAt.subtract(const Duration(minutes: 10, seconds: 1));
    final state = await setup(plannedAt);
    await withClock(Clock(() => now), () async {
      final meal = (await state.db.mealDao.getMealById(1))!.toDomain();
      final running =
          state.container.read(scheduledCaregiverMealDecisionProvider)(
            state.harness.runtimeContext,
            MealMonitorContext(activeMeal: meal),
            meal,
          );
      for (var i = 0; i < 100 && state.harness.pendingDeadlines.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect((await state.db.mealDao.getMealById(1))!.status, 'planned');
      expect(
        state.harness.pendingDeadlines,
        contains(now.add(const Duration(seconds: 1))),
      );
      now = now.add(const Duration(seconds: 1));
      state.harness.dispatchTick(now);
      await running;
      expect(
        (await state.db.mealDao.getMealById(1))!.status,
        'waiting-for-bolus',
      );
    });
  });

  test(
    'response observed before acceptance is picked up without restart',
    () async {
      final plannedAt = DateTime(2026, 11, 22, 12);
      final now = plannedAt.subtract(const Duration(minutes: 9));
      final state = await setup(plannedAt);
      final row = await state.db
          .customSelect(
            'SELECT outcome_json FROM family_meal_decision_receipts WHERE request_id=?',
            variables: [const Variable('request')],
          )
          .getSingle();
      await state.db.customStatement(
        'DELETE FROM family_meal_decision_receipts',
      );
      await withClock(Clock(() => now), () async {
        final meal = (await state.db.mealDao.getMealById(1))!.toDomain();
        final running =
            state.container.read(scheduledCaregiverMealDecisionProvider)(
              state.harness.runtimeContext,
              MealMonitorContext(activeMeal: meal),
              meal,
            );
        for (
          var i = 0;
          i < 100 && state.harness.pendingDeadlines.isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect((await state.db.mealDao.getMealById(1))!.status, 'planned');
        await state.db.customInsert(
          'INSERT INTO family_meal_decision_receipts (request_id,owner_uid,source_id,meal_id,acceptance_token,outcome_json,created_at) VALUES (?,?,?,?,?,?,?)',
          variables: [
            const Variable('request'),
            const Variable('child'),
            const Variable('source'),
            const Variable(1),
            const Variable('token'),
            Variable(row.read<String>('outcome_json')),
            Variable(now.millisecondsSinceEpoch),
          ],
        );
        state.harness.runtimeContext.emitSignal('scheduled_meal_receipt:1');
        await running;
        expect(
          (await state.db.mealDao.getMealById(1))!.status,
          'waiting-for-bolus',
        );
      });
    },
  );

  test(
    'manual start before the due time cancels scheduled activation',
    () async {
      final plannedAt = DateTime(2026, 11, 22, 12);
      var now = plannedAt.subtract(const Duration(minutes: 10, seconds: 1));
      final state = await setup(plannedAt);
      await withClock(Clock(() => now), () async {
        final meal = (await state.db.mealDao.getMealById(1))!.toDomain();
        final running =
            state.container.read(scheduledCaregiverMealDecisionProvider)(
              state.harness.runtimeContext,
              MealMonitorContext(activeMeal: meal),
              meal,
            );
        for (
          var i = 0;
          i < 100 && state.harness.pendingDeadlines.isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await state.db.customStatement(
          "UPDATE meal SET status='eating' WHERE id=1",
        );
        now = now.add(const Duration(seconds: 1));
        state.harness.dispatchTick(now);
        await running;
        expect((await state.db.mealDao.getMealById(1))!.status, 'eating');
        final history = await state.db.mealAdvisorResultDao
            .getMealStatusHistory(1);
        expect(history, isNot(contains('waiting-for-bolus')));
      });
    },
  );

  test(
    'accepted scheduled prebolus remains recoverable after planned time',
    () async {
      final plannedAt = DateTime(2026, 11, 22, 12);
      final state = await setup(plannedAt);
      await withClock(
        Clock.fixed(plannedAt.add(const Duration(minutes: 1))),
        () async {
          final recovered = await state.container.refresh(
            getNearestMealProvider.future,
          );
          expect(recovered?.id, 1);
          await state.container.read(scheduledCaregiverMealDecisionProvider)(
            state.harness.runtimeContext,
            MealMonitorContext(activeMeal: recovered),
            recovered!,
          );
          expect(
            (await state.db.mealDao.getMealById(1))!.status,
            'waiting-for-bolus',
          );
        },
      );
    },
  );

  test(
    'stale time binding and unscheduled receipt never start prebolus',
    () async {
      final plannedAt = DateTime(2026, 11, 22, 12);
      final now = plannedAt.subtract(const Duration(minutes: 5));
      for (final options in [
        (scheduled: false, boundAt: plannedAt.millisecondsSinceEpoch),
        (
          scheduled: true,
          boundAt: plannedAt
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        ),
      ]) {
        final state = await setup(
          plannedAt,
          scheduled: options.scheduled,
          boundAt: options.boundAt,
        );
        await withClock(Clock.fixed(now), () async {
          final meal = (await state.db.mealDao.getMealById(1))!.toDomain();
          await state.container.read(scheduledCaregiverMealDecisionProvider)(
            state.harness.runtimeContext,
            MealMonitorContext(activeMeal: meal),
            meal,
          );
          expect((await state.db.mealDao.getMealById(1))!.status, 'planned');
        });
      }
    },
  );
}
