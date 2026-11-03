import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/pending_meal_completion_requests.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_schedule_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/finished_eating_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_summary_reminder_notification.dart';
import 'package:diabeatthis/core/notifications/handlers/notification_response_handler.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_upcoming_list.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_list_today.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_to_ui_test_router.dart';
import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/foreground_ui/notification_response_wire.dart';
import '../../helpers/foreground_ui/pump_database_streams.dart';
import '../../helpers/localized_material_app.dart';
import '../../helpers/regression/recording_foreground_platform.dart';

void main() {
  testWidgets('serialized Agree response opens completion for a late meal', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 3, 12);
    late ForegroundUiHarness harness;
    late ForegroundToUiTestRouter router;
    late int mealId;
    await tester.runAsync(() async {
      router = ForegroundToUiTestRouter();
      harness = await ForegroundUiHarness.create(
        foregroundOverrides: [
          taskEventRouterProvider.overrideWithValue(router),
        ],
      );
      mealId = await _insertMeal(harness.uiDb, 'Late meal', 'eating');
    });
    try {
      await tester.runAsync(
        () => withClock(Clock.fixed(now), () async {
          final wire = notificationResponseWire(
            FinishedEatingNotificationEvent(mealId: mealId),
            'agree',
          );
          ExternalEventHandler(harness.runtimeContext).handle(wire);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }),
      );

      final rows = await tester.runAsync(() async {
        return (
          await harness.uiDb.mealDao.getMealById(mealId),
          await harness.foregroundDb.mealDao.getMealById(mealId),
          await harness.foregroundDb
              .select(harness.foregroundDb.mealStatusHistory)
              .get(),
        );
      });
      expect(rows!.$1?.status, 'eating');
      expect(rows.$2?.status, 'eating');
      expect(rows.$3.map((row) => row.status), ['eating']);
      expect(router.messages, hasLength(1));
      expect(router.messages.single, {
        'event': 'task_open_meal_completion',
        'data': {'mealId': mealId},
      });
      final pending = await tester.runAsync(
        () => harness.foregroundContainer
            .read(pendingMealCompletionRequestsProvider)
            .pending(),
      );
      expect(pending, {mealId});
    } finally {
      await tester.runAsync(harness.close);
    }
  });

  testWidgets('snooze and dismiss preserve meal and unrelated entity', (
    tester,
  ) async {
    late ForegroundUiHarness harness;
    late ForegroundToUiTestRouter router;
    late int mealId;
    late int otherMealId;
    await tester.runAsync(() async {
      router = ForegroundToUiTestRouter();
      harness = await ForegroundUiHarness.create(
        foregroundOverrides: [
          taskEventRouterProvider.overrideWithValue(router),
        ],
      );
      mealId = await _insertMeal(harness.uiDb, 'Target', 'eating');
      otherMealId = await _insertMeal(harness.uiDb, 'Other', 'planned');
    });
    try {
      final handler = ExternalEventHandler(harness.runtimeContext);
      for (final action in ['snooze', 'empty']) {
        handler.handle(
          notificationResponseWire(
            FinishedEatingNotificationEvent(mealId: mealId),
            action,
          ),
        );
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      final rows = await tester.runAsync(
        () async => (
          await harness.uiDb.mealDao.getMealById(mealId),
          await harness.uiDb.mealDao.getMealById(otherMealId),
          await harness.uiDb.select(harness.uiDb.mealStatusHistory).get(),
        ),
      );
      expect(rows!.$1?.status, 'eating');
      expect(rows.$2?.status, 'planned');
      expect(rows.$3.map((row) => row.status), ['eating', 'planned']);
      expect(router.messages, isEmpty);
    } finally {
      await tester.runAsync(harness.close);
    }
  });

  testWidgets('reminder Agree summarizes a ready meal once and refreshes UI', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 3, 12);
    late ForegroundUiHarness harness;
    late int mealId;
    late int otherMealId;
    await tester.runAsync(() async {
      harness = await ForegroundUiHarness.create();
      mealId = await _insertReadyMeal(harness.uiDb, 'Ready meal');
      otherMealId = await _insertMeal(harness.uiDb, 'Other meal', 'planned');
    });
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.uiContainer,
          child: localizedMaterialApp(
            home: const Scaffold(body: MealListToday()),
          ),
        ),
      );
      await pumpDatabaseStreams(tester);
      expect(find.text('Ready meal'), findsOneWidget);
      await tester.runAsync(
        () => withClock(Clock.fixed(now), () async {
          final handler = ExternalEventHandler(harness.runtimeContext);
          for (var i = 0; i < 2; i++) {
            handler.handle(
              notificationResponseWire(
                MealSummaryReminderNotificationEvent(mealId: mealId),
                'agree',
              ),
            );
          }
          // Both response callbacks may arrive before the first save completes.
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }),
      );
      await pumpDatabaseStreams(tester);
      final rows = await tester.runAsync(
        () async => (
          await harness.uiDb.mealDao.getMealById(mealId),
          await harness.foregroundDb.mealDao.getMealById(mealId),
          await harness.uiDb.mealIngredientsDao.getMealIngredientsForMeal(
            mealId,
          ),
          await harness.foregroundDb
              .select(harness.foregroundDb.mealSnapshot)
              .get(),
          await harness.uiDb.mealDao.getMealById(otherMealId),
        ),
      );
      expect(rows!.$1?.status, 'summarized');
      expect(rows.$2?.status, 'summarized');
      expect(rows.$3.single.consumedAmount, 100);
      expect(
        rows.$4.where(
          (snapshot) =>
              snapshot.mealId == mealId && snapshot.snapshotType == 'consumed',
        ),
        hasLength(1),
      );
      expect(rows.$5?.status, 'planned');
      expect(find.text('Ready meal'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(harness.close);
    }
  });

  testWidgets('wrong and deleted meal IDs leave valid meal unchanged', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 3, 12);
    late ForegroundUiHarness harness;
    late ForegroundToUiTestRouter router;
    late int validId;
    late int deletedId;
    await tester.runAsync(() async {
      router = ForegroundToUiTestRouter();
      harness = await ForegroundUiHarness.create(
        foregroundOverrides: [
          taskEventRouterProvider.overrideWithValue(router),
        ],
      );
      validId = await _insertMeal(harness.uiDb, 'Valid', 'eating');
      deletedId = await _insertMeal(harness.uiDb, 'Deleted', 'planned');
      await harness.uiDb.mealDao.deleteMealAndGeneratedData(deletedId);
    });
    try {
      await tester.runAsync(
        () => withClock(Clock.fixed(now), () async {
          final handler = ExternalEventHandler(harness.runtimeContext);
          for (final id in [999999, deletedId]) {
            handler.handle(
              notificationResponseWire(
                FinishedEatingNotificationEvent(mealId: id),
                'agree',
              ),
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }),
      );
      final rows = await tester.runAsync(
        () async => (
          await harness.uiDb.mealDao.getMealById(validId),
          await harness.foregroundDb
              .select(harness.foregroundDb.mealStatusHistory)
              .get(),
        ),
      );
      expect(rows!.$1?.status, 'eating');
      expect(rows.$2.map((row) => row.status), ['eating']);
      expect(router.messages, isEmpty);
      final pending = await tester.runAsync(
        () => harness.foregroundContainer
            .read(pendingMealCompletionRequestsProvider)
            .pending(),
      );
      expect(pending, isEmpty);
    } finally {
      await tester.runAsync(harness.close);
    }
  });

  testWidgets(
    'activity notification Agree and skip update their own occurrences',
    (tester) async {
      final now = DateTime.now().add(const Duration(minutes: 1));
      late ForegroundUiHarness harness;
      late int agreedId;
      late int skippedId;
      late int unrelatedId;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          meals: false,
          activities: true,
        );
        final activityId = await harness.uiDb
            .into(harness.uiDb.activity)
            .insert(
              ActivityCompanion.insert(
                name: 'Run',
                percentagePre: 10,
                percentagePost: 20,
              ),
            );
        Future<int> occurrence(String mode) => harness.uiDb
            .into(harness.uiDb.activityOccurrence)
            .insert(
              ActivityOccurrenceCompanion.insert(
                activityId: activityId,
                startedAt: now
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch,
                actionAt: now.millisecondsSinceEpoch,
                confirmationMode: mode,
                durationMinutes: const Value(30),
              ),
            );
        agreedId = await occurrence('before');
        skippedId = await occurrence('before');
        unrelatedId = await occurrence('before');
        harness.startMonitoring();
      });
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.uiContainer,
            child: localizedMaterialApp(
              home: const Scaffold(body: ActivityUpcomingList()),
            ),
          ),
        );
        await pumpDatabaseStreams(tester);
        expect(find.text('Run'), findsNWidgets(3));
        final rows = await tester.runAsync(
          () => withClock(Clock.fixed(now), () async {
            final handler = ExternalEventHandler(harness.runtimeContext);
            handler.handle(
              notificationResponseWire(
                _activityNotification(agreedId, now),
                'agree',
              ),
            );
            handler.handle(
              notificationResponseWire(
                _activityNotification(agreedId, now),
                'agree',
              ),
            );
            handler.handle(
              notificationResponseWire(
                _activityNotification(skippedId, now),
                'skip',
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 70));
            return (
              await harness.uiDb.select(harness.uiDb.activityOccurrence).get(),
              await harness.foregroundDb
                  .select(harness.foregroundDb.activityLog)
                  .get(),
            );
          }),
        );
        await pumpDatabaseStreams(tester);
        final agreed = rows!.$1.singleWhere((row) => row.id == agreedId);
        final skipped = rows.$1.singleWhere((row) => row.id == skippedId);
        final unrelated = rows.$1.singleWhere((row) => row.id == unrelatedId);
        expect(agreed.status, 'planned');
        expect(agreed.activityLogId, isNotNull);
        expect(skipped.status, 'skipped');
        expect(unrelated.status, 'pending');
        expect(
          rows.$2.where((log) => log.activityId == agreed.activityId),
          hasLength(1),
        );
        expect(find.text('Run'), findsNWidgets(3));
        expect(
          find.text(
            lookupAppLocalizations(const Locale('pl')).activitySchedulePlanned,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            lookupAppLocalizations(const Locale('pl')).activityScheduleSkipped,
          ),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(harness.close);
      }
    },
  );

  testWidgets(
    'native notification callback forwards production wire response',
    (tester) async {
      late ForegroundUiHarness harness;
      late int mealId;
      late ForegroundToUiTestRouter router;
      final original = FlutterForegroundTaskPlatform.instance;
      final platform = ResponseForwardingForegroundPlatform();
      await tester.runAsync(() async {
        router = ForegroundToUiTestRouter();
        harness = await ForegroundUiHarness.create(
          foregroundOverrides: [
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
        mealId = await _insertMeal(harness.uiDb, 'Native late meal', 'eating');
      });
      try {
        platform.onData = (data) => ExternalEventHandler(
          harness.runtimeContext,
        ).handle(jsonDecode(data as String) as Map<String, dynamic>);
        FlutterForegroundTaskPlatform.instance = platform;
        await tester.runAsync(
          () => withClock(Clock.fixed(DateTime(2026, 11, 3, 12)), () async {
            await onDidReceiveNotificationResponse(
              NotificationResponse(
                notificationResponseType:
                    NotificationResponseType.selectedNotificationAction,
                actionId: 'agree',
                payload: jsonEncode(
                  FinishedEatingNotificationEvent(mealId: mealId).toPayload(),
                ),
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 40));
          }),
        );
        expect(platform.messages, hasLength(1));
        final meal = await tester.runAsync(
          () => harness.uiDb.mealDao.getMealById(mealId),
        );
        expect(meal?.status, 'eating');
        expect(router.messages, hasLength(1));
        expect(router.messages.single, {
          'event': 'task_open_meal_completion',
          'data': {'mealId': mealId},
        });
        final pending = await tester.runAsync(
          () => harness.foregroundContainer
              .read(pendingMealCompletionRequestsProvider)
              .pending(),
        );
        expect(pending, {mealId});
      } finally {
        FlutterForegroundTaskPlatform.instance = original;
        await tester.runAsync(harness.close);
      }
    },
  );
}

ActivityScheduleNotificationEvent _activityNotification(int id, DateTime now) =>
    ActivityScheduleNotificationEvent(
      occurrenceId: id,
      activityName: 'Run',
      startsAt: now.add(const Duration(hours: 1)),
    );

Future<int> _insertMeal(DatabaseImpl db, String name, String status) async {
  final at = DateTime(2026, 11, 3, 11).millisecondsSinceEpoch;
  final id = await db
      .into(db.meal)
      .insert(
        MealCompanion.insert(name: name, plannedAt: at, status: Value(status)),
      );
  await db
      .into(db.mealStatusHistory)
      .insert(
        MealStatusHistoryCompanion.insert(
          mealId: id,
          status: status,
          createdAt: Value(at),
        ),
      );
  return id;
}

Future<int> _insertReadyMeal(DatabaseImpl db, String name) async {
  final ingredientId = await db
      .into(db.ingredient)
      .insert(
        IngredientCompanion.insert(
          name: 'Test rice',
          carbsPer100g: 20,
          fiberPer100g: 0,
          fatPer100g: 0,
          proteinPer100g: 0,
          nutritionConfidence: .9,
        ),
      );
  final mealId = await _insertMeal(db, name, 'eaten');
  await db
      .into(db.mealIngredients)
      .insert(
        MealIngredientsCompanion.insert(
          mealId: mealId,
          ingredientId: ingredientId,
          amount: const Value(100),
          quantityConfidence: .9,
          consumedAmount: const Value(100),
          consumedConfidence: const Value(.9),
        ),
      );
  return mealId;
}
