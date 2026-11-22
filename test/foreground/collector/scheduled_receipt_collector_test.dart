import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal_advisor/remote/scheduled_meal_decision_journal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/collector/next_meal_collector.dart';
import 'package:diabeatthis/foreground/event/internal/meal_event.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  test(
    'late accepted scheduled receipt wakes monitor once after restart',
    () async {
      final now = DateTime(2026, 11, 22, 12, 1);
      final plannedAt = now.subtract(const Duration(minutes: 1));
      final server = DriftIsolate.inCurrent(() => NativeDatabase.memory());
      addTearDown(server.shutdownAll);
      final db = DatabaseImpl(await server.connect());
      addTearDown(db.close);
      final writer = DatabaseImpl(await server.connect());
      addTearDown(writer.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(harness.dispose);
      await db.customInsert(
        "INSERT INTO meal(id,name,planned_at,status) VALUES(1,'Dinner',?,'planned')",
        variables: [Variable(plannedAt.millisecondsSinceEpoch)],
      );
      final journal = ScheduledMealDecisionJournal(db);
      await journal.remember(1, plannedAt, uid: 'child', requestId: 'request');
      await journal.complete(1, plannedAt);

      await withClock(Clock.fixed(now), () async {
        final collector = NextMealCollector();
        collector.start(
          CollectorContext.fromRuntimeContext(harness.runtimeContext),
        );
        addTearDown(collector.dispose);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(harness.emittedEvents.whereType<NextMealEvent>(), isEmpty);
        await writer.customInsert(
          'INSERT INTO family_meal_decision_receipts(request_id,owner_uid,source_id,meal_id,acceptance_token,outcome_json,created_at) VALUES(?,?,?,?,?,?,?)',
          variables: [
            const Variable('stale-request'),
            const Variable('child'),
            const Variable('source'),
            const Variable(1),
            const Variable('token'),
            Variable(jsonEncode({
              'source': 'caregiver',
              'scheduled': true,
              'plannedAt': plannedAt.millisecondsSinceEpoch,
              'decision': 'insulinThenWait',
              'minutes': 10,
            })),
            Variable(now.millisecondsSinceEpoch),
          ],
          updates: {writer.familyMealDecisionReceipts},
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(harness.emittedEvents.whereType<NextMealEvent>(), isEmpty);
        await writer.customInsert(
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
                'scheduled': true,
                'plannedAt': plannedAt.millisecondsSinceEpoch,
                'decision': 'insulinThenWait',
                'minutes': 10,
              }),
            ),
            Variable(now.millisecondsSinceEpoch),
          ],
          updates: {writer.familyMealDecisionReceipts},
        );
        for (
          var i = 0;
          i < 100 && harness.emittedEvents.whereType<NextMealEvent>().isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        final events = harness.emittedEvents
            .whereType<NextMealEvent>()
            .toList();
        expect(events, hasLength(1));
        expect(events.single.mealId, 1);
        expect(events.single.when, plannedAt);
        await (writer.update(writer.familyMealDecisionReceipts)).write(
          const FamilyMealDecisionReceiptsCompanion(acknowledged: Value(true)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(harness.emittedEvents.whereType<NextMealEvent>(), hasLength(1));
      });
    },
  );
}
