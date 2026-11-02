import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/finished_eating_response_event.dart';
import 'package:diabeatthis/common/events/task_event_payload.dart';
import 'package:diabeatthis/common/meal/pending_meal_completion_recovery.dart';
import 'package:diabeatthis/common/meal/pending_meal_completion_requests.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/finished_eating_event_notification.dart';
import 'package:diabeatthis/core/notifications/handlers/notification_response_handler.dart';
import 'package:diabeatthis/core/notifications/mappers/android_notification_details_mapper.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event_handler.dart';
import 'package:diabeatthis/foreground/event/router/task_event_router.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/fake_runtime_harness.dart';

class ColdCompletionTaskRouter extends TaskEventRouter {
  final sent = <TaskEventPayload>[];

  @override
  void send(TaskEventPayload payload) => sent.add(payload);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_foreground_task/methods');
  final now = DateTime(2026, 11, 1, 19, 52);
  late DatabaseImpl db;
  late PendingMealCompletionRequests requests;
  late ColdCompletionTaskRouter router;
  late FakeRuntimeHarness harness;
  late List<MethodCall> platformCalls;
  var mealNumber = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = const PendingMealCompletionRequests();
    db = DatabaseImpl(NativeDatabase.memory());
    router = ColdCompletionTaskRouter();
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          platformCalls.add(call);
          return null;
        });
    harness = FakeRuntimeHarness(
      container: ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pendingMealCompletionRequestsProvider.overrideWithValue(requests),
          taskEventRouterProvider.overrideWithValue(router),
        ],
      ),
    );
  });

  tearDown(() async {
    await harness.dispose();
    await db.close();
    await FlutterForegroundTask.streamSubscription?.cancel();
    FlutterForegroundTask.receivePort?.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<int> eatingMeal(Duration? elapsed) async {
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Meal ${++mealNumber}',
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

  Future<List<int>> recover({void Function(int)? replayFresh}) => withClock(
    Clock.fixed(now),
    () => PendingMealCompletionRecovery(
      database: db,
      requests: requests,
    ).recover(replayFresh: replayFresh),
  );

  Future<void> agree(int mealId) => withClock(
    Clock.fixed(now),
    () => NotificationResponseEventHandler().handleFinishedEatingResponse(
      FinishedEatingResponseEvent.agree(mealId: mealId),
      harness.runtimeContext,
    ),
  );

  test('only finished-eating Agree launches Android UI', () {
    final actions = FinishedEatingNotificationEvent(
      mealId: 1,
    ).toAndroidNotificationDetails().actions!;
    expect(
      actions.singleWhere((action) => action.id == 'agree').showsUserInterface,
      isTrue,
    );
    expect(
      actions.singleWhere((action) => action.id == 'snooze').showsUserInterface,
      isFalse,
    );
    expect(
      EatNowNotificationEvent(mealId: 2, minutes: 10)
          .toAndroidNotificationDetails()
          .actions!
          .every((action) => !action.showsUserInterface),
      isTrue,
    );
  });

  test(
    'background response preserves UI port and persists intent before dispatch',
    () async {
      FlutterForegroundTask.initCommunicationPort();
      final uiPort = FlutterForegroundTask.receivePort;
      await onDidReceiveBackgroundNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'agree',
          payload: jsonEncode(
            FinishedEatingNotificationEvent(mealId: 42).toPayload(),
          ),
        ),
      );
      expect(FlutterForegroundTask.receivePort, same(uiPort));
      expect(await const PendingMealCompletionRequests().pending(), {42});
      expect(platformCalls.single.method, 'sendData');
      expect(
        jsonDecode(
          platformCalls.single.arguments as String,
        )['data']['data']['mealId'],
        42,
      );
    },
  );

  for (final elapsed in [const Duration(hours: 5), null]) {
    test(
      'cold UI recovers late or unknown start without foreground delivery: $elapsed',
      () async {
        final id = await eatingMeal(elapsed);
        await const PendingMealCompletionRequests().request(id);
        final before = await db.select(db.mealStatusHistory).get();
        expect(await recover(), [id]);
        expect(await requests.pending(), {id});
        expect((await db.mealDao.getMealById(id))!.status, 'eating');
        expect(await db.select(db.mealStatusHistory).get(), before);
        await requests.acknowledge(id);
        expect(await recover(), isEmpty);
      },
    );
  }

  test(
    'foreground late dispatch remains recoverable if its UI message is lost',
    () async {
      final id = await eatingMeal(const Duration(hours: 5));
      await agree(id);
      expect(router.sent, hasLength(1));
      expect(harness.emittedEvents, isEmpty);
      expect(await recover(), [id]);
    },
  );

  test(
    'fresh pending reply resumes foreground path without opening UI concurrently',
    () async {
      final id = await eatingMeal(const Duration(minutes: 20));
      await requests.request(id);
      final replayed = <int>[];
      expect(await recover(replayFresh: replayed.add), isEmpty);
      expect(replayed, [id]);
      await agree(id);
      expect(await requests.pending(), {id});
      expect(router.sent, isEmpty);
      expect(harness.emittedEvents, [
        FinishedEatingResponseEvent.agree(mealId: id),
      ]);
      await db.mealDao.updateMealStatus(id, 'eaten', occurredAt: now);
      expect(await recover(), isEmpty);
      expect(await requests.pending(), isEmpty);
    },
  );

  test(
    'fresh reply missed before a monitor waiter exists remains replayable',
    () async {
      final id = await eatingMeal(const Duration(minutes: 20));
      await requests.request(id);
      expect(harness.activeWaitersCount, 0);
      await agree(id);
      final replayed = <int>[];
      expect(await recover(replayFresh: replayed.add), isEmpty);
      expect(replayed, [id]);
      expect(await requests.pending(), {id});
      expect((await db.mealDao.getMealById(id))!.status, 'eating');
    },
  );

  for (final status in [
    'interrupted',
    'summarized',
    'waiting-for-bolus',
    'bolused-waiting',
  ]) {
    test(
      'recovery removes stale $status request and leaves other meals pending',
      () async {
        final stale = await eatingMeal(const Duration(hours: 5));
        final active = await eatingMeal(const Duration(hours: 5));
        await requests.request(stale);
        await requests.request(active);
        await db.mealDao.updateMealStatus(stale, status);
        expect(await recover(), [active]);
        expect(await requests.pending(), {active});
        expect((await db.mealDao.getMealById(stale))!.status, status);
      },
    );
  }

  test(
    'foreground stale reply acknowledges durable request without status mutation',
    () async {
      final id = await eatingMeal(const Duration(hours: 5));
      await requests.request(id);
      await db.mealDao.interruptMeal(id);
      await agree(id);
      expect(await requests.pending(), isEmpty);
      expect(router.sent, isEmpty);
      expect(harness.emittedEvents, isEmpty);
      expect((await db.mealDao.getMealById(id))!.status, 'interrupted');
    },
  );
}
