import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/event/internal/activity_temp_target_settings_changed.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/activity_monitor_task.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/executors/idle_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/executors/monitor_active_activity_executor.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseImpl db;
  late SharedPreferences prefs;
  late TempTargetService service;
  late FakeNotificationsController notifications;
  late FakeRuntimeHarness harness;
  late ActivityMonitorTask task;
  late DateTime now;
  late List<Map<String, dynamic>> posts;
  Map<String, dynamic>? remote;
  var sequence = 0;

  setUp(() async {
    now = DateTime(2026, 10, 29, 12);
    posts = [];
    remote = null;
    sequence = 0;
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
      nightscoutTokenKey: 'token',
      nightscoutTempTargetsEnabledKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    service = TempTargetService(
      preferences: () async => prefs,
      database: () => db,
      writer: NightscoutTempTargetWriter(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(remote == null ? [] : [remote]),
              200,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          posts.add(body);
          remote = {...body, '_id': 'target-${posts.length}'};
          return http.Response(jsonEncode([remote]), 201);
        }),
      ),
    );
    notifications = FakeNotificationsController();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((_) async => prefs),
        databaseProvider.overrideWithValue(db),
        tempTargetServiceProvider.overrideWithValue(service),
        notificationsControllerForegroundProvider.overrideWithValue(
          notifications,
        ),
      ],
    );
    harness = FakeRuntimeHarness(container: container);
    task = ActivityMonitorTask();
  });

  Future<void> settle() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> waitForCancellation() async {
    final elapsed = Stopwatch()..start();
    while ((posts.lastOrNull?['duration'] != 0 ||
            task.state is! ActivityMonitorStateIdle) &&
        elapsed.elapsed < const Duration(seconds: 3)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await settle();
  }

  Future<void> runMonitor() async {
    final running = task.run(harness.runtimeContext).catchError((Object error) {
      if (error is! TaskCancelledException) throw error;
    });
    addTearDown(() async {
      harness.cancel();
      await running;
      await harness.dispose();
    });
    await settle();
  }

  Future<int> seed(DateTime start, {int? minutes}) async {
    final id = await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Activity ${sequence++}',
            percentagePre: 0,
            percentagePost: 0,
            durationMinutes: Value(minutes),
          ),
        );
    return db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: id,
            startedAt: start.millisecondsSinceEpoch,
          ),
        );
  }

  List<TempTargetNotificationEvent> offers() => notifications.shownEvents
      .whereType<TempTargetNotificationEvent>()
      .where((event) => event.requestId != null)
      .toList();

  Future<void> approve(TempTargetNotificationEvent offer) async {
    expect(
      await service.respond(
        requestId: offer.requestId!,
        targetType: offer.targetType,
        entityId: offer.entityId,
        approved: true,
      ),
      TempTargetSendResult.sent,
    );
    await settle();
  }

  test(
    'existing monitor asks at minus sixty and stops a fixed-duration target when the log closes',
    () => withClock(Clock(() => now), () async {
      final start = now.add(const Duration(hours: 2));
      final id = await seed(start, minutes: 60);
      await runMonitor();
      expect(offers(), isEmpty);
      now = start.subtract(const Duration(minutes: 61));
      harness.dispatchTick(now);
      await settle();
      expect(offers(), isEmpty);
      now = start.subtract(const Duration(minutes: 60));
      harness.dispatchTick(now);
      await settle();
      expect(offers(), hasLength(1));
      expect(offers().single.durationMinutes, 120);
      await approve(offers().single);
      now = start;
      harness.dispatchTick(now);
      await settle();
      expect(task.state, isA<MonitorActiveActivityExecutor>());
      now = start.add(const Duration(minutes: 10));
      await db.activityDao.finishActivityLogIfOpen(id, start, now);
      await waitForCancellation();
      expect(posts, hasLength(2));
      expect(posts.last['duration'], 0);
      expect(task.state, isA<ActivityMonitorStateIdle>());
    }),
  );

  test(
    'active monitor asks before expiry and renews a manual session only after consent',
    () => withClock(Clock(() => now), () async {
      await seed(now.subtract(const Duration(minutes: 10)));
      await runMonitor();
      expect(task.state, isA<MonitorActiveActivityExecutor>());
      await approve(offers().single);
      now = now.add(const Duration(minutes: 19));
      harness.dispatchTick(now);
      await settle();
      expect(offers(), hasLength(1));
      now = now.add(const Duration(minutes: 1));
      harness.dispatchTick(now);
      await settle();
      expect(offers(), hasLength(2));
      expect(offers().last.renewal, isTrue);
      expect(posts, hasLength(1));
      await approve(offers().last);
      expect(posts.last['duration'], 90);
    }),
  );

  test(
    'monitoring an ongoing session does not block a later session target offer',
    () => withClock(Clock(() => now), () async {
      final first = await seed(now.subtract(const Duration(minutes: 10)));
      final second = await seed(
        now.add(const Duration(minutes: 90)),
        minutes: 45,
      );
      await runMonitor();
      expect(offers().map((event) => event.entityId), [first]);
      now = now.add(const Duration(minutes: 30));
      harness.dispatchTick(now);
      await settle();
      expect(task.state, isA<MonitorActiveActivityExecutor>());
      expect(offers().map((event) => event.entityId), [first, second]);
      expect(posts, isEmpty);
    }),
  );

  test(
    'enabling target writes re-enters a running manual monitor without losing its session',
    () => withClock(Clock(() => now), () async {
      await prefs.setBool(nightscoutTempTargetsEnabledKey, false);
      final id = await seed(now.subtract(const Duration(minutes: 10)));
      await runMonitor();
      expect(task.state, isA<MonitorActiveActivityExecutor>());
      expect(offers(), isEmpty);
      await prefs.setBool(nightscoutTempTargetsEnabledKey, true);
      harness.dispatchEventToTask(
        task,
        const ActivityTempTargetSettingsChanged(),
      );
      await settle();
      expect(task.state, isA<MonitorActiveActivityExecutor>());
      expect(offers().single.entityId, id);
      expect(posts, isEmpty);
    }),
  );

  test(
    'startup cleans up an owned target from an activity closed while the monitor was stopped',
    () => withClock(Clock(() => now), () async {
      final start = now.subtract(const Duration(minutes: 10));
      final id = await seed(start, minutes: 60);
      final offer = (await service.activityOffer(id))!;
      await approve(offer);
      now = now.add(const Duration(minutes: 5));
      await db.activityDao.finishActivityLogIfOpen(id, start, now);
      await runMonitor();
      await waitForCancellation();
      expect(posts.last['duration'], 0);
      expect(task.state, isA<ActivityMonitorStateIdle>());
    }),
  );
}
