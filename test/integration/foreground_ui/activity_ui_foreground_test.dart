import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/monitoring/activity_monitoring_phase.dart';
import 'package:diabeatthis/common/widgets/status_info_card.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show ActivityOccurrenceCompanion, ActivityOccurrenceData;
import 'package:diabeatthis/core/drift/entity/activity.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_schedule_notification.dart';
import 'package:diabeatthis/features/activity/presentation/screens/activity_page.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_picker_sheet.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_upcoming_list.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_completed_activity_card.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_fab.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_status_card.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_schedule_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/foreground_ui/pump_database_streams.dart';
import '../../helpers/localized_material_app.dart';

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(finder, findsWidgets);
}

Future<void> pumpUntilGone(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(finder, findsNothing);
}

Future<void> withHarnessCleanup(
  WidgetTester tester,
  ForegroundUiHarness harness,
  Future<void> Function() body,
) async {
  try {
    await body();
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(harness.close);
  }
}

void main() {
  testWidgets(
    'dashboard shows an active session and finishing it stops foreground monitoring',
    (tester) async {
      final startedAt = DateTime(2026, 11, 3, 10);
      final now = startedAt.add(const Duration(minutes: 20));
      late ForegroundUiHarness harness;
      late int logId;

      await withClock(Clock.fixed(now), () async {
        await tester.runAsync(() async {
          harness = await ForegroundUiHarness.create(
            meals: false,
            activities: true,
          );
          final activityId = await harness.uiDb
              .into(harness.uiDb.activity)
              .insert(
                ActivityCompanion.insert(
                  name: 'Morning run',
                  percentagePre: 10,
                  percentagePost: 20,
                  durationMinutes: const Value(60),
                ),
              );
          logId = await harness.uiDb
              .into(harness.uiDb.activityLog)
              .insert(
                ActivityLogCompanion.insert(
                  activityId: activityId,
                  startedAt: startedAt.millisecondsSinceEpoch,
                ),
              );
          harness.startMonitoring();
        });
        await withHarnessCleanup(tester, harness, () async {
          await tester.runAsync(() async {
            for (var attempt = 0; attempt < 40; attempt++) {
              if (harness.activityStatus?.phase ==
                  ActivityMonitoringPhase.active) {
                return;
              }
              await Future<void>.delayed(const Duration(milliseconds: 25));
            }
          });
          expect(harness.activityStatus?.phase, ActivityMonitoringPhase.active);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: harness.uiContainer,
              child: localizedMaterialApp(
                home: const Scaffold(
                  body: SingleChildScrollView(child: DashboardStatusCard()),
                ),
              ),
            ),
          );
          await pumpUntilFound(tester, find.byType(StatusInfoCard));
          expect(find.byType(StatusInfoCard), findsOneWidget);
          expect(find.text('Morning run'), findsOneWidget);

          final lang = lookupAppLocalizations(const Locale('pl'));
          await tester.tap(find.byTooltip(lang.dashboardFinishActivityTooltip));
          await tester.pump();
          for (var attempt = 0; attempt < 100; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 25)),
            );
            await tester.pump(const Duration(milliseconds: 25));
            if (harness.activityStatus?.phase == ActivityMonitoringPhase.idle) {
              break;
            }
          }
          await tester.pump();

          expect(harness.activityStatus?.phase, ActivityMonitoringPhase.idle);
          final endedAt = await tester.runAsync(
            () async => (await harness.uiDb.activityDao.getActivityLogById(
              logId,
            )).endedAt,
          );
          expect(endedAt, isNotNull);
          expect(harness.activityStatus?.phase, ActivityMonitoringPhase.idle);
          expect(find.byType(StatusInfoCard), findsNothing);
          expect(find.byType(DashboardCompletedActivityCard), findsOneWidget);
          expect(
            find.text(
              lookupAppLocalizations(const Locale('pl')).activitySummaryReady,
            ),
            findsOneWidget,
          );
        });
      });
    },
  );

  testWidgets('foreground auto-end publishes a summary-ready dashboard card', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 3, 12);
    final startedAt = now.subtract(const Duration(minutes: 2));
    late ForegroundUiHarness harness;
    late int logId;

    await withClock(Clock.fixed(now), () async {
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          meals: false,
          activities: true,
        );
        final activityId = await harness.uiDb
            .into(harness.uiDb.activity)
            .insert(
              ActivityCompanion.insert(
                name: 'Short ride',
                percentagePre: 5,
                percentagePost: 10,
                durationMinutes: const Value(1),
              ),
            );
        logId = await harness.uiDb
            .into(harness.uiDb.activityLog)
            .insert(
              ActivityLogCompanion.insert(
                activityId: activityId,
                startedAt: startedAt.millisecondsSinceEpoch,
              ),
            );
        harness.startMonitoring();
      });

      await withHarnessCleanup(tester, harness, () async {
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 40; attempt++) {
            final log = await harness.uiDb.activityDao.getActivityLogById(
              logId,
            );
            if (log.endedAt != null) return;
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.uiContainer,
            child: localizedMaterialApp(
              home: const Scaffold(
                body: SingleChildScrollView(child: DashboardStatusCard()),
              ),
            ),
          ),
        );
        await pumpUntilFound(
          tester,
          find.text(
            lookupAppLocalizations(const Locale('pl')).activitySummaryReady,
          ),
        );

        expect(find.text('Short ride'), findsOneWidget);
        expect(
          find.text(
            lookupAppLocalizations(const Locale('pl')).activitySummaryReady,
          ),
          findsOneWidget,
        );
        expect(find.byType(DashboardCompletedActivityCard), findsOneWidget);
      });
    });
  });

  testWidgets('dashboard cancels a planned activity through its real action', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 3, 9);
    final startsAt = now.add(const Duration(minutes: 30));
    late ForegroundUiHarness harness;
    late int logId;

    await withClock(Clock.fixed(now), () async {
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          meals: false,
          activities: true,
        );
        final activityId = await harness.uiDb
            .into(harness.uiDb.activity)
            .insert(
              ActivityCompanion.insert(
                name: 'Evening yoga',
                percentagePre: 0,
                percentagePost: 5,
                durationMinutes: const Value(45),
              ),
            );
        logId = await harness.uiDb
            .into(harness.uiDb.activityLog)
            .insert(
              ActivityLogCompanion.insert(
                activityId: activityId,
                startedAt: startsAt.millisecondsSinceEpoch,
              ),
            );
        harness.startMonitoring();
      });
      await withHarnessCleanup(tester, harness, () async {
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 40; attempt++) {
            if (harness.activityStatus?.phase ==
                    ActivityMonitoringPhase.preparing &&
                harness.activityStatus?.activityLogId == logId) {
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        });
        expect(
          harness.activityStatus?.phase,
          ActivityMonitoringPhase.preparing,
        );
        expect(harness.activityStatus?.activityLogId, logId);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.uiContainer,
            child: localizedMaterialApp(
              home: const Scaffold(
                body: SingleChildScrollView(child: DashboardStatusCard()),
              ),
            ),
          ),
        );
        await pumpUntilFound(tester, find.byType(StatusInfoCard));
        expect(find.byType(StatusInfoCard), findsOneWidget);
        expect(find.text('Evening yoga'), findsOneWidget);

        final lang = lookupAppLocalizations(const Locale('pl'));
        await tester.tap(find.byTooltip(lang.dashboardCancelPlannedActivity));
        await tester.pump();
        for (var attempt = 0; attempt < 100; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump(const Duration(milliseconds: 25));
          if (harness.activityStatus?.phase == ActivityMonitoringPhase.idle) {
            break;
          }
        }
        await pumpUntilGone(tester, find.byType(StatusInfoCard));

        final deletedLog = await tester.runAsync(
          () => harness.uiDb.activityDao.getActivityLogByIdOrNull(logId),
        );
        expect(deletedLog, isNull);
        expect(harness.activityStatus?.phase, ActivityMonitoringPhase.idle);
        expect(find.byType(StatusInfoCard), findsNothing);
      });
    });
  });

  testWidgets(
    'creating and starting a second activity is rejected while the first is active',
    (tester) async {
      final startedAt = DateTime(2026, 11, 3, 10);
      final now = startedAt.add(const Duration(minutes: 20));
      late ForegroundUiHarness harness;
      late int firstLogId;

      await withClock(Clock.fixed(now), () async {
        await tester.runAsync(() async {
          harness = await ForegroundUiHarness.create(
            meals: false,
            activities: true,
          );
          final activityId = await harness.uiDb
              .into(harness.uiDb.activity)
              .insert(
                ActivityCompanion.insert(
                  name: 'Morning run',
                  percentagePre: 10,
                  percentagePost: 20,
                  durationMinutes: const Value(60),
                ),
              );
          firstLogId = await harness.uiDb
              .into(harness.uiDb.activityLog)
              .insert(
                ActivityLogCompanion.insert(
                  activityId: activityId,
                  startedAt: startedAt.millisecondsSinceEpoch,
                ),
              );
          harness.startMonitoring();
        });
        await withHarnessCleanup(tester, harness, () async {
          await tester.runAsync(() async {
            for (var attempt = 0; attempt < 40; attempt++) {
              if (harness.activityStatus?.phase ==
                      ActivityMonitoringPhase.active &&
                  harness.activityStatus?.activityLogId == firstLogId) {
                return;
              }
              await Future<void>.delayed(const Duration(milliseconds: 25));
            }
          });

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: harness.uiContainer,
              child: localizedMaterialApp(
                home: Scaffold(
                  body: const SingleChildScrollView(
                    child: DashboardStatusCard(),
                  ),
                  floatingActionButton: const DashboardFAB(),
                ),
              ),
            ),
          );
          await pumpUntilFound(tester, find.byType(StatusInfoCard));
          expect(find.text('Morning run'), findsOneWidget);
          expect(harness.activityStatus?.phase, ActivityMonitoringPhase.active);

          final lang = lookupAppLocalizations(const Locale('pl'));
          await tester.tap(find.byIcon(Icons.add));
          await tester.pump();
          await pumpUntilFound(tester, find.text(lang.dashboardStartActivity));
          await tester.tap(find.text(lang.dashboardStartActivity));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final pickActivityButton = find.widgetWithText(
            OutlinedButton,
            lang.activityPickTitle,
          );
          final tappablePickActivityButton = pickActivityButton.hitTestable();
          await pumpUntilFound(tester, tappablePickActivityButton);
          await tester.tap(tappablePickActivityButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final createActivityAction = find.descendant(
            of: find.byType(ActivityPickerSheet),
            matching: find.text(lang.activityCreateTitle),
          );
          final tappableCreateActivityAction = createActivityAction
              .hitTestable();
          await pumpUntilFound(tester, tappableCreateActivityAction);
          await tester.tap(tappableCreateActivityAction);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          await pumpUntilFound(
            tester,
            find.byKey(const ValueKey('activity-name-field')).hitTestable(),
          );
          await tester.enterText(
            find.byKey(const ValueKey('activity-name-field')),
            'Evening ride',
          );
          await tester.enterText(
            find.byKey(const ValueKey('activity-percentage-pre-field')),
            '5',
          );
          await tester.enterText(
            find.byKey(const ValueKey('activity-percentage-post-field')),
            '10',
          );
          tester.testTextInput.hide();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(
            find.widgetWithText(FilledButton, lang.commonCreate),
          );
          await tester.pump();
          await pumpUntilGone(
            tester,
            find.byKey(const ValueKey('activity-name-field')),
          );
          await pumpUntilGone(tester, find.byType(ActivityPickerSheet));
          await pumpUntilFound(tester, find.text('Evening ride'));
          await tester.pump(const Duration(milliseconds: 300));
          final startNowButton = find
              .widgetWithText(FilledButton, lang.activityStartNow)
              .hitTestable();
          await pumpUntilFound(tester, startNowButton);
          await tester.tap(startNowButton);
          await tester.pump();

          // Drain the save and its database streams before checking the invariant.
          await pumpDatabaseStreams(tester);
          final databaseState = await tester.runAsync(
            () async => (
              await harness.uiDb.select(harness.uiDb.activity).get(),
              await harness.uiDb.select(harness.uiDb.activityLog).get(),
            ),
          );
          expect(
            databaseState?.$1.map((activity) => activity.name),
            containsAll(['Morning run', 'Evening ride']),
          );
          expect(databaseState?.$2, hasLength(1));
          expect(databaseState?.$2.single.id, firstLogId);
          expect(harness.activityStatus?.phase, ActivityMonitoringPhase.active);
          expect(harness.activityStatus?.activityLogId, firstLogId);
        });
      });
    },
    // Regression: starting another activity inserts a second open log while
    // both foreground and dashboard select only the first open log.
  );

  testWidgets('canceling activity detail edits leaves the database unchanged', (
    tester,
  ) async {
    final startedAt = DateTime(2026, 11, 3, 10);
    final now = startedAt.add(const Duration(minutes: 20));
    late ForegroundUiHarness harness;
    late int activityId;

    await withClock(Clock.fixed(now), () async {
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          meals: false,
          activities: true,
        );
        activityId = await harness.uiDb
            .into(harness.uiDb.activity)
            .insert(
              ActivityCompanion.insert(
                name: 'Morning run',
                percentagePre: 10,
                percentagePost: 20,
                durationMinutes: const Value(30),
              ),
            );
        await harness.uiDb
            .into(harness.uiDb.activityLog)
            .insert(
              ActivityLogCompanion.insert(
                activityId: activityId,
                startedAt: startedAt.millisecondsSinceEpoch,
              ),
            );
        harness.startMonitoring();
      });
      await withHarnessCleanup(tester, harness, () async {
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 40; attempt++) {
            if (harness.activityStatus?.phase ==
                ActivityMonitoringPhase.active) {
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.uiContainer,
            child: localizedMaterialApp(
              home: Scaffold(body: ActivityPage(activityId: activityId)),
            ),
          ),
        );
        final lang = lookupAppLocalizations(const Locale('pl'));
        await pumpUntilFound(tester, find.byTooltip(lang.activityEditTooltip));
        await tester.tap(find.byTooltip(lang.activityEditTooltip));
        await pumpUntilFound(tester, find.byType(TextFormField));
        await tester.enterText(find.byType(TextFormField).at(1), '60');
        await tester.tap(find.text(lang.settingsCancel));
        await pumpUntilFound(tester, find.text('Morning run'));

        final durationMinutes = await tester.runAsync(
          () async => (await harness.uiDb.activityDao.getActivityById(
            activityId,
          )).durationMinutes,
        );
        expect(durationMinutes, 30);
        expect(harness.activityStatus?.phase, ActivityMonitoringPhase.active);
      });
    });
  });

  testWidgets(
    'editing activity duration in the UI updates its running foreground deadline',
    (tester) async {
      var now = DateTime(2026, 11, 3, 12);
      final startedAt = now;
      late ForegroundUiHarness harness;
      late int activityId;
      late int logId;

      await withClock(Clock(() => now), () async {
        await tester.runAsync(() async {
          harness = await ForegroundUiHarness.create(
            meals: false,
            activities: true,
          );
          activityId = await harness.uiDb
              .into(harness.uiDb.activity)
              .insert(
                ActivityCompanion.insert(
                  name: 'Duration edit run',
                  percentagePre: 10,
                  percentagePost: 20,
                  durationMinutes: const Value(30),
                ),
              );
          logId = await harness.uiDb
              .into(harness.uiDb.activityLog)
              .insert(
                ActivityLogCompanion.insert(
                  activityId: activityId,
                  startedAt: startedAt.millisecondsSinceEpoch,
                ),
              );
          harness.startMonitoring();
        });
        await withHarnessCleanup(tester, harness, () async {
          await tester.runAsync(() async {
            for (var attempt = 0; attempt < 40; attempt++) {
              if (harness.activityStatus?.phase ==
                  ActivityMonitoringPhase.active) {
                return;
              }
              await Future<void>.delayed(const Duration(milliseconds: 25));
            }
          });

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: harness.uiContainer,
              child: localizedMaterialApp(
                home: Scaffold(body: ActivityPage(activityId: activityId)),
              ),
            ),
          );
          final lang = lookupAppLocalizations(const Locale('pl'));
          await pumpUntilFound(
            tester,
            find.byTooltip(lang.activityEditTooltip),
          );
          await tester.tap(find.byTooltip(lang.activityEditTooltip));
          await pumpUntilFound(tester, find.byType(TextFormField));
          await tester.enterText(find.byType(TextFormField).at(1), '60');
          await tester.tap(find.text(lang.settingsSave));
          await pumpUntilFound(tester, find.text('Duration edit run'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );

          now = startedAt.add(const Duration(minutes: 30));
          harness.scheduler.tick(now);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          final log = await tester.runAsync(
            () => harness.uiDb.activityDao.getActivityLogById(logId),
          );
          expect(log?.endedAt, isNull);
          expect(harness.activityStatus?.phase, ActivityMonitoringPhase.active);
        });
      });
    },
    // Regression: the monitor snapshots the default duration at activity start.
  );

  testWidgets('upcoming activity move action reschedules its occurrence', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 3, 9);
    final startsAt = DateTime(2026, 11, 5, 12);
    late ForegroundUiHarness harness;
    late int occurrenceId;

    await withClock(Clock.fixed(now), () async {
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          meals: false,
          activities: true,
        );
        final activityId = await harness.uiDb
            .into(harness.uiDb.activity)
            .insert(
              ActivityCompanion.insert(
                name: 'Saturday swim',
                percentagePre: 0,
                percentagePost: 5,
                durationMinutes: const Value(45),
              ),
            );
        occurrenceId = await harness.uiDb
            .into(harness.uiDb.activityOccurrence)
            .insert(
              ActivityOccurrenceCompanion.insert(
                activityId: activityId,
                startedAt: startsAt.millisecondsSinceEpoch,
                durationMinutes: const Value(45),
                actionAt: now
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch,
                confirmationMode: 'before',
              ),
            );
        harness.startMonitoring();
        harness.scheduler.startTask(
          const ActivityScheduleTask(),
          harness.runtimeContext,
        );
      });

      await withHarnessCleanup(tester, harness, () async {
        final originalPrompt = ActivityScheduleNotificationEvent(
          occurrenceId: occurrenceId,
          activityName: 'Saturday swim',
          startsAt: startsAt,
        );
        expect(harness.notifications.contains(originalPrompt), isFalse);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.uiContainer,
            child: localizedMaterialApp(
              home: const Scaffold(body: ActivityUpcomingList()),
            ),
          ),
        );
        await pumpUntilFound(tester, find.text('Saturday swim'));

        final lang = lookupAppLocalizations(const Locale('pl'));
        await tester.tap(find.text(lang.activityScheduleMove));
        await pumpUntilFound(tester, find.byType(DatePickerDialog));
        await tester.tap(find.text('6').last);
        await tester.pump();
        await tester.tap(find.text('OK').last);
        await pumpUntilFound(tester, find.byType(TimePickerDialog));
        await tester.tap(find.text('OK').last);
        await tester.pump();

        List<ActivityOccurrenceData>? uiRows;
        List<ActivityOccurrenceData>? foregroundRows;
        var querying = false;
        for (var attempt = 0; attempt < 150; attempt++) {
          if (!querying) {
            querying = true;
            Future.wait([
              harness.uiDb.select(harness.uiDb.activityOccurrence).get(),
              harness.foregroundDb
                  .select(harness.foregroundDb.activityOccurrence)
                  .get(),
            ]).then((rows) {
              uiRows = rows[0];
              foregroundRows = rows[1];
              querying = false;
            });
          }
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          if (uiRows?.length == 2 && foregroundRows?.length == 2) break;
        }
        expect(uiRows, hasLength(2));
        expect(foregroundRows, hasLength(2));
        final updatedRows = uiRows!;
        final foregroundUpdatedRows = foregroundRows!;
        expect(
          updatedRows.singleWhere((row) => row.id == occurrenceId).status,
          'skipped',
        );
        expect(
          foregroundUpdatedRows
              .singleWhere((row) => row.id == occurrenceId)
              .status,
          'skipped',
        );
        expect(
          updatedRows.singleWhere((row) => row.id != occurrenceId).startedAt,
          DateTime(2026, 11, 6, 12).millisecondsSinceEpoch,
        );
        expect(
          foregroundUpdatedRows
              .singleWhere((row) => row.id != occurrenceId)
              .startedAt,
          DateTime(2026, 11, 6, 12).millisecondsSinceEpoch,
        );
        expect(harness.notifications.contains(originalPrompt), isFalse);
      });
    });
  });
}
