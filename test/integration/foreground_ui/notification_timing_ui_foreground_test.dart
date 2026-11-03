import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_schedule_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/finished_eating_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_summary_reminder_notification.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_upcoming_list.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/meal_status_changed_event.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_schedule_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/foreground_ui/notification_response_wire.dart';
import '../../helpers/foreground_ui/timed_notifications_controller.dart';
import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'finished-eating reminder waits five minutes, snoozes five more, and completion stops repeats',
    (tester) async {
      var now = DateTime(2026, 11, 3, 12);
      late ForegroundUiHarness harness;
      late TimedNotificationsController notifications;
      late int mealId;

      await withClock(Clock(() => now), () async {
        await tester.runAsync(() async {
          notifications = TimedNotificationsController(now: () => now);
          harness = await ForegroundUiHarness.create(
            meals: true,
            activities: false,
            notificationController: notifications,
          );
          mealId = await harness.uiDb
              .into(harness.uiDb.meal)
              .insert(
                MealCompanion.insert(
                  name: 'Timed lunch',
                  plannedAt: now.millisecondsSinceEpoch,
                  status: const Value('eating'),
                ),
              );
          await harness.uiDb
              .into(harness.uiDb.mealStatusHistory)
              .insert(
                MealStatusHistoryCompanion.insert(
                  mealId: mealId,
                  status: 'eating',
                  createdAt: Value(now.millisecondsSinceEpoch),
                ),
              );
          harness.startMonitoring();
        });

        try {
          await _settleForeground(tester);
          harness.scheduler.emitEvent(MealStartedEatingEvent(mealId: mealId));
          await _settleForeground(tester);

          now = now.add(const Duration(minutes: 4, seconds: 59));
          harness.scheduler.tick(now);
          await _settleForeground(tester);
          expect(
            notifications.shownAt.where(
              (entry) => entry.event is FinishedEatingNotificationEvent,
            ),
            isEmpty,
          );

          now = DateTime(2026, 11, 3, 12, 5);
          harness.scheduler.tick(now);
          await _settleForeground(tester);
          final firstReminder = notifications.shownAt
              .where((entry) => entry.event is FinishedEatingNotificationEvent)
              .single;
          expect(firstReminder.at, now);
          expect(
            (firstReminder.event as FinishedEatingNotificationEvent).mealId,
            mealId,
          );

          ExternalEventHandler(
            harness.runtimeContext,
          ).handle(notificationResponseWire(firstReminder.event, 'snooze'));
          await _settleForeground(tester);
          now = DateTime(2026, 11, 3, 12, 9, 59);
          harness.scheduler.tick(now);
          await _settleForeground(tester);
          expect(
            notifications.shownAt
                .where(
                  (entry) => entry.event is FinishedEatingNotificationEvent,
                )
                .length,
            1,
          );

          now = DateTime(2026, 11, 3, 12, 10);
          harness.scheduler.tick(now);
          await _settleForeground(tester);
          final reminders = notifications.shownAt
              .where((entry) => entry.event is FinishedEatingNotificationEvent)
              .toList();
          expect(reminders, hasLength(2));
          expect(reminders.last.at, now);
          expect(
            (reminders.last.event as FinishedEatingNotificationEvent).mealId,
            mealId,
          );

          ExternalEventHandler(
            harness.runtimeContext,
          ).handle(notificationResponseWire(reminders.last.event, 'agree'));
          await _settleForeground(tester);
          final finishedMeals = await _waitForMealFinished(
            tester,
            harness,
            mealId,
            notifications,
          );
          expect(finishedMeals.uiMeal?.status, 'eaten');
          expect(finishedMeals.foregroundMeal?.status, 'eaten');
          expect(
            finishedMeals.history.where((entry) => entry.status == 'eaten'),
            hasLength(1),
          );
          expect(notifications.contains(firstReminder.event), isFalse);
          expect(notifications.scheduledAt, hasLength(1));
          expect(
            notifications.scheduledAt.single.event,
            isA<MealSummaryReminderNotificationEvent>(),
          );
          expect(
            notifications.scheduledAt.single.delay,
            const Duration(minutes: 2),
          );
          expect(notifications.scheduledAt.single.at, now);

          now = DateTime(2026, 11, 3, 12, 15);
          harness.scheduler.tick(now);
          await _settleForeground(tester);
          expect(
            notifications.shownAt
                .where(
                  (entry) => entry.event is FinishedEatingNotificationEvent,
                )
                .length,
            2,
          );
        } finally {
          await tester.runAsync(harness.close);
        }
      });
    },
  );

  testWidgets(
    'activity confirmation arrives at action time and deleting a later occurrence prevents its prompt',
    (tester) async {
      var now = DateTime(2026, 11, 3, 6);
      late ForegroundUiHarness harness;
      late TimedNotificationsController notifications;
      late int dueOccurrenceId;
      late int deletedOccurrenceId;
      final dueActionAt = now.add(const Duration(minutes: 5));
      final deletedActionAt = now.add(const Duration(minutes: 7));

      await withClock(Clock(() => now), () async {
        await tester.runAsync(() async {
          notifications = TimedNotificationsController(now: () => now);
          harness = await ForegroundUiHarness.create(
            meals: false,
            activities: true,
            notificationController: notifications,
          );
          final activityId = await harness.uiDb
              .into(harness.uiDb.activity)
              .insert(
                ActivityCompanion.insert(
                  name: 'Timed run',
                  percentagePre: 5,
                  percentagePost: 10,
                  durationMinutes: const Value(45),
                ),
              );
          Future<int> occurrence(DateTime actionAt) => harness.uiDb
              .into(harness.uiDb.activityOccurrence)
              .insert(
                ActivityOccurrenceCompanion.insert(
                  activityId: activityId,
                  startedAt: now
                      .add(Duration(hours: actionAt == dueActionAt ? 2 : 3))
                      .millisecondsSinceEpoch,
                  actionAt: actionAt.millisecondsSinceEpoch,
                  confirmationMode: 'before',
                  durationMinutes: const Value(45),
                ),
              );

          dueOccurrenceId = await occurrence(dueActionAt);
          deletedOccurrenceId = await occurrence(deletedActionAt);
          harness.startMonitoring();
          harness.scheduler.startTask(
            const ActivityScheduleTask(),
            harness.runtimeContext,
          );
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
          await _pumpUntilFound(
            tester,
            find.byTooltip(
              lookupAppLocalizations(
                const Locale('pl'),
              ).activityOccurrenceDelete,
            ),
          );
          expect(notifications.shownAt, isEmpty);

          // The list is ordered by start time; delete the second occurrence using
          // its production UI action before its confirmation deadline.
          await tester.tap(
            find
                .byTooltip(
                  lookupAppLocalizations(
                    const Locale('pl'),
                  ).activityOccurrenceDelete,
                )
                .last,
          );
          await _settleForeground(tester);
          final deletedRow = await tester.runAsync(() async {
            return (await (harness.uiDb.select(
              harness.uiDb.activityOccurrence,
            )..where((row) => row.id.equals(deletedOccurrenceId))).getSingle());
          });
          expect(deletedRow?.status, 'deleted');

          now = dueActionAt.subtract(const Duration(milliseconds: 1));
          harness.scheduler.tick(now);
          await _settleForeground(tester);
          expect(notifications.shownAt, isEmpty);

          now = dueActionAt;
          harness.scheduler.tick(now);
          await _settleForeground(tester);
          expect(notifications.shownAt, hasLength(1));
          final prompt = notifications.shownAt.single;
          expect(prompt.at, dueActionAt);
          expect(prompt.event, isA<ActivityScheduleNotificationEvent>());
          expect(
            (prompt.event as ActivityScheduleNotificationEvent).occurrenceId,
            dueOccurrenceId,
          );

          now = deletedActionAt;
          harness.scheduler.tick(now);
          await _settleForeground(tester);
          expect(notifications.shownAt, hasLength(1));
          expect(
            notifications.shownAt
                .map((entry) => entry.event)
                .whereType<ActivityScheduleNotificationEvent>()
                .map((event) => event.occurrenceId),
            [dueOccurrenceId],
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(harness.close);
        }
      });
    },
  );

  // Regression: ActivityScheduleService.delete/remove does not cancel an
  // already shown activity confirmation notification.
  testWidgets(
    'deleting a prompted activity removes its already visible notification',
    (tester) async {
      var now = DateTime(2026, 11, 3, 6);
      late ForegroundUiHarness harness;
      late TimedNotificationsController notifications;
      late int occurrenceId;
      final actionAt = now.add(const Duration(minutes: 5));

      await withClock(Clock(() => now), () async {
        await tester.runAsync(() async {
          notifications = TimedNotificationsController(now: () => now);
          harness = await ForegroundUiHarness.create(
            meals: false,
            activities: true,
            notificationController: notifications,
          );
          final activityId = await harness.uiDb
              .into(harness.uiDb.activity)
              .insert(
                ActivityCompanion.insert(
                  name: 'Prompted run',
                  percentagePre: 5,
                  percentagePost: 10,
                  durationMinutes: const Value(45),
                ),
              );
          occurrenceId = await harness.uiDb
              .into(harness.uiDb.activityOccurrence)
              .insert(
                ActivityOccurrenceCompanion.insert(
                  activityId: activityId,
                  startedAt: now
                      .add(const Duration(hours: 2))
                      .millisecondsSinceEpoch,
                  actionAt: actionAt.millisecondsSinceEpoch,
                  confirmationMode: 'before',
                  durationMinutes: const Value(45),
                ),
              );
          harness.startMonitoring();
          harness.scheduler.startTask(
            const ActivityScheduleTask(),
            harness.runtimeContext,
          );
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
          await _pumpUntilFound(
            tester,
            find.byTooltip(
              lookupAppLocalizations(
                const Locale('pl'),
              ).activityOccurrenceDelete,
            ),
          );
          now = actionAt;
          harness.scheduler.tick(now);
          await _settleForeground(tester);
          final prompt = notifications.shownAt.single.event;
          expect(prompt, isA<ActivityScheduleNotificationEvent>());
          expect(
            (prompt as ActivityScheduleNotificationEvent).occurrenceId,
            occurrenceId,
          );

          await tester.tap(
            find.byTooltip(
              lookupAppLocalizations(
                const Locale('pl'),
              ).activityOccurrenceDelete,
            ),
          );
          await _settleForeground(tester);

          // This assertion records the intended behavior. It is skipped until
          // occurrence edits cancel the OS notification keyed by occurrenceId.
          expect(notifications.contains(prompt), isFalse);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(harness.close);
        }
      });
    },
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(finder, findsWidgets);
}

Future<void> _settleForeground(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<
  ({
    MealData? uiMeal,
    MealData? foregroundMeal,
    List<MealStatusHistoryData> history,
  })
>
_waitForMealFinished(
  WidgetTester tester,
  ForegroundUiHarness harness,
  int mealId,
  TimedNotificationsController notifications,
) async {
  MealData? uiMeal;
  MealData? foregroundMeal;
  List<MealStatusHistoryData>? history;
  var querying = false;
  Future<
    ({
      MealData? uiMeal,
      MealData? foregroundMeal,
      List<MealStatusHistoryData> history,
    })
  >
  queryRows() async => (
    uiMeal: await harness.uiDb.mealDao.getMealById(mealId),
    foregroundMeal: await harness.foregroundDb.mealDao.getMealById(mealId),
    history: await (harness.uiDb.select(
      harness.uiDb.mealStatusHistory,
    )..where((row) => row.mealId.equals(mealId))).get(),
  );

  for (var attempt = 0; attempt < 150; attempt++) {
    if (!querying) {
      querying = true;
      queryRows().then((result) {
        uiMeal = result.uiMeal;
        foregroundMeal = result.foregroundMeal;
        history = result.history;
        querying = false;
      });
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 10));
    if (uiMeal?.status == 'eaten' &&
        foregroundMeal?.status == 'eaten' &&
        history?.where((entry) => entry.status == 'eaten').length == 1 &&
        notifications.scheduledAt.isNotEmpty) {
      return (
        uiMeal: uiMeal,
        foregroundMeal: foregroundMeal,
        history: history!,
      );
    }
  }
  expect(uiMeal?.status, 'eaten');
  expect(foregroundMeal?.status, 'eaten');
  expect(history?.where((entry) => entry.status == 'eaten'), hasLength(1));
  expect(notifications.scheduledAt, isNotEmpty);
  return (
    uiMeal: uiMeal,
    foregroundMeal: foregroundMeal,
    history: history ?? const <MealStatusHistoryData>[],
  );
}
