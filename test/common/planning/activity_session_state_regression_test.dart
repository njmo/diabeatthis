import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/activity/activity_session_state.dart';
import 'package:diabeatthis/common/activity/watch_activity_start_boundary.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_log_card.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_details_data.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  final now = DateTime(2026, 11, 7, 12);
  final cases = [
    (
      name: 'future reservation',
      start: now.add(const Duration(days: 4)),
      end: null,
      state: ActivitySessionState.planned,
    ),
    (
      name: 'exact start',
      start: now,
      end: null,
      state: ActivitySessionState.active,
    ),
    (
      name: 'already started',
      start: now.subtract(const Duration(minutes: 10)),
      end: null,
      state: ActivitySessionState.active,
    ),
    (
      name: 'finished',
      start: now.subtract(const Duration(hours: 1)),
      end: now.subtract(const Duration(minutes: 5)),
      state: ActivitySessionState.finished,
    ),
  ];
  for (final item in cases) {
    test(
      '${item.name} has the same state in model, SQL and active stream',
      () => withClock(Clock.fixed(now), () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        await db.customStatement(
          "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Training',20,30)",
        );
        await db.customStatement(
          'INSERT INTO activity_log(activity_id,started_at,ended_at) VALUES(1,?,?)',
          [item.start.millisecondsSinceEpoch, item.end?.millisecondsSinceEpoch],
        );
        expect(
          activitySessionState(startedAt: item.start, endedAt: item.end),
          item.state,
        );
        final model = ActivityLogDetailsData(
          id: 1,
          activityId: 1,
          activityName: 'Training',
          percentagePre: 20,
          percentagePost: 30,
          durationMinutes: 43,
          startedAt: item.start,
          endedAt: item.end,
          intensity: null,
          notes: null,
          isSynced: false,
          createdAt: now,
          updatedAt: now,
        );
        expect(model.isActive, item.state == ActivitySessionState.active);
        final expected = item.state == ActivitySessionState.active ? 1 : null;
        expect(
          (await db.activityDao.getActiveActivityLogOrNull())?.id,
          expected,
        );
        expect(
          (await db.activityDao.getActiveActivityLogView())?.log.id,
          expected,
        );
        expect(
          (await db.activityDao.watchActiveActivityLogView().first)?.log.id,
          expected,
        );
        expect(
          (await db.activityDao.getPendingActivityLogView())?.log.id,
          item.end == null ? 1 : null,
        );
      }),
    );
  }
  test(
    'active stream re-evaluates at start and cancels its timer on disposal',
    () {
      fakeAsync((async) {
        withClock(Clock(() => now.add(async.elapsed)), () {
          final source = StreamController<List<DateTime>>(sync: true);
          final events = <DateTime?>[];
          final start = now.add(const Duration(minutes: 10));
          final subscription = watchActivityStartBoundary(
            source: source.stream,
            startedAt: (DateTime time) => time,
          ).listen(events.add);
          source.add([start]);
          expect(events, [null]);
          async.elapse(const Duration(minutes: 9));
          expect(events, [null]);
          async.elapse(const Duration(minutes: 1));
          expect(events, [null, start]);
          source.add([]);
          expect(events.last, isNull);
          source.add([now.add(const Duration(days: 1))]);
          subscription.cancel();
          async.flushMicrotasks();
          expect(async.nonPeriodicTimerCount, 0);
          source.close();
          async.flushMicrotasks();
        });
      });
    },
  );
  testWidgets(
    'shared history card is planned until the start boundary and retains duration',
    (tester) async {
      final base = tester.binding.clock.now();
      final start = base.add(const Duration(minutes: 1));
      await withClock(Clock(() => tester.binding.clock.now()), () async {
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: ActivityLogCard(
                name: 'Training',
                startedAt: start,
                endedAt: null,
                durationMinutes: 43,
                onTap: null,
              ),
            ),
          ),
        );
        expect(find.text('Zaplanowane'), findsOneWidget);
        expect(find.text('Aktywna'), findsNothing);
        expect(find.text('43 min'), findsOneWidget);
        await tester.pump(const Duration(minutes: 1));
        expect(find.text('Zaplanowane'), findsNothing);
        expect(find.text('Aktywna'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );
  test(
    'paused stream resumes from newest rows and closing clears pending boundary',
    () {
      fakeAsync((async) {
        withClock(Clock(() => now.add(async.elapsed)), () {
          final source = StreamController<List<DateTime>>(sync: true);
          final events = <DateTime?>[];
          var done = false;
          final start = now.add(const Duration(minutes: 10));
          final sub = watchActivityStartBoundary(
            source: source.stream,
            startedAt: (DateTime t) => t,
          ).listen(events.add, onDone: () => done = true);
          source.add([start]);
          sub.pause();
          async.elapse(const Duration(minutes: 20));
          source.add([]);
          sub.resume();
          async.flushMicrotasks();
          expect(events.every((e) => e == null), true);
          source.add([now.add(const Duration(days: 1))]);
          source.close();
          async.flushMicrotasks();
          expect(done, true);
          expect(async.nonPeriodicTimerCount, 0);
        });
      });
    },
  );
  testWidgets('shared card rechecks start when application resumes', (
    tester,
  ) async {
    var current = now;
    final start = now.add(const Duration(hours: 1));
    await withClock(Clock(() => current), () async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ActivityLogCard(
              name: 'Training',
              startedAt: start,
              endedAt: null,
              onTap: null,
            ),
          ),
        ),
      );
      expect(find.text('Zaplanowane'), findsWidgets);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      current = now.add(const Duration(hours: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Aktywna'), findsOneWidget);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ActivityLogCard(
              name: 'Training',
              startedAt: start,
              endedAt: current,
              onTap: null,
            ),
          ),
        ),
      );
      expect(find.text('Zakończona'), findsOneWidget);
      expect(find.text('Aktywna'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
