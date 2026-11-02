import 'package:clock/clock.dart';
import 'package:diabeatthis/app/event/task/task_event.dart';
import 'package:diabeatthis/common/events/data/notification/finished_eating_response_event.dart';
import 'package:diabeatthis/common/events/data/task/task_open_meal_completion_payload.dart';
import 'package:diabeatthis/common/events/task_event_payload.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event_handler.dart';
import 'package:diabeatthis/foreground/event/router/task_event_router.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

class CompletionRecordingTaskRouter extends TaskEventRouter {
  final sent = <TaskEventPayload>[];

  @override
  void send(TaskEventPayload payload) => sent.add(payload);
}

void main() {
  final now = DateTime(2026, 11, 1, 19, 52);
  late DatabaseImpl db;
  late CompletionRecordingTaskRouter router;
  late FakeRuntimeHarness harness;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    router = CompletionRecordingTaskRouter();
    harness = FakeRuntimeHarness(
      container: ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          taskEventRouterProvider.overrideWithValue(router),
        ],
      ),
    );
  });
  tearDown(() async {
    await harness.dispose();
    await db.close();
  });

  Future<int> eatingMeal(Duration? elapsed) async {
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Meal',
            plannedAt: now.millisecondsSinceEpoch,
            status: Value(elapsed == null ? 'eating' : 'planned'),
          ),
        );
    if (elapsed != null) {
      await db.mealDao.updateMealStatus(
        id,
        'eating',
        occurredAt: now.subtract(elapsed),
      );
    }
    return id;
  }

  Future<void> agree(int id) => withClock(
    Clock.fixed(now),
    () => NotificationResponseEventHandler().handleFinishedEatingResponse(
      FinishedEatingResponseEvent.agree(mealId: id),
      harness.runtimeContext,
    ),
  );

  test('normal finish response retains the existing monitor path', () async {
    final id = await eatingMeal(const Duration(minutes: 20));
    await agree(id);
    expect(router.sent, isEmpty);
    expect(harness.emittedEvents, [
      FinishedEatingResponseEvent.agree(mealId: id),
    ]);
  });

  for (final elapsed in [
    const Duration(minutes: 60),
    const Duration(hours: 5),
    null,
  ]) {
    test(
      'late or missing start opens completion without inventing an end: $elapsed',
      () async {
        final id = await eatingMeal(elapsed);
        final before = await db.select(db.mealStatusHistory).get();
        await agree(id);
        expect(harness.emittedEvents, isEmpty);
        expect(router.sent, hasLength(1));
        expect(
          (router.sent.single as TaskOpenMealCompletionPayload).mealId,
          id,
        );
        expect((await db.mealDao.getMealById(id))!.status, 'eating');
        expect(await db.select(db.mealStatusHistory).get(), before);
        final decoded = TaskEvent.fromJson(
          router.sent.single.toTaskEventJson(),
        );
        expect(decoded, isA<TaskOpenMealCompletionEvent>());
      },
    );
  }

  test(
    'current add-on uses its own start, not the original meal five hours ago',
    () async {
      final id = await eatingMeal(const Duration(hours: 5));
      await db.mealDao.updateMealStatus(
        id,
        'eaten',
        occurredAt: now.subtract(const Duration(hours: 4)),
      );
      await db.mealDao.updateMealStatus(
        id,
        'eating-extra',
        occurredAt: now.subtract(const Duration(minutes: 10)),
      );
      await agree(id);
      expect(router.sent, isEmpty);
      expect(harness.emittedEvents, [
        FinishedEatingResponseEvent.agree(mealId: id),
      ]);
    },
  );

  test('stale finish reply does not reopen an interrupted meal', () async {
    final id = await eatingMeal(const Duration(hours: 5));
    await db.mealDao.interruptMeal(id);
    await agree(id);
    expect(router.sent, isEmpty);
    expect(harness.emittedEvents, isEmpty);
  });

  test(
    'snooze keeps its existing behavior without forcing the summary',
    () async {
      const response = FinishedEatingResponseEvent.snooze(mealId: 42);
      await NotificationResponseEventHandler().handleFinishedEatingResponse(
        response,
        harness.runtimeContext,
      );
      expect(harness.emittedEvents, [response]);
      expect(router.sent, isEmpty);
    },
  );
}
