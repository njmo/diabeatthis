import 'package:diabeatthis/common/events/data/notification/activity_finished_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/eat_now_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/meal_suggestion_response_event.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_carbs_request_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_finished_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_suggestion_notification.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/aaps_carbs_request_acknowledged_event.dart';
import 'package:diabeatthis/foreground/providers/task_event_router_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/foreground_to_ui_test_router.dart';
import '../../helpers/foreground_ui/foreground_ui_harness.dart';
import '../../helpers/foreground_ui/notification_response_wire.dart';

void main() {
  testWidgets('serialized Eat Now response routes its meal and action', (
    tester,
  ) async {
    late ForegroundUiHarness harness;
    await tester.runAsync(() async {
      harness = await ForegroundUiHarness.create(
        meals: false,
        activities: false,
      );
    });
    try {
      final inbox = harness.runtimeContext
          .openEventInbox<EatNowResponseEvent>();
      final notification = EatNowNotificationEvent(mealId: 41, minutes: 15);
      final handler = ExternalEventHandler(harness.runtimeContext);

      for (final (action, expected) in [
        ('eating', EatNowResponseEvent.eating(mealId: 41)),
        ('dismiss', EatNowResponseEvent.dismiss(mealId: 41)),
        ('empty', EatNowResponseEvent.empty(mealId: 41)),
      ]) {
        handler.handle(notificationResponseWire(notification, action));
        expect(await inbox.nextBatch(), [expected]);
      }
      inbox.close();
    } finally {
      await tester.runAsync(harness.close);
    }
  });

  testWidgets(
    'serialized meal suggestion response routes its meal and action',
    (tester) async {
      late ForegroundUiHarness harness;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          meals: false,
          activities: false,
        );
      });
      try {
        final inbox = harness.runtimeContext
            .openEventInbox<MealSuggestionResponseEvent>();
        final notification = MealSuggestionNotificationEvent(
          mealId: 72,
          minutes: 10,
          decision: MealDecision.bolusAndEatNow,
          carbs: 24,
        );

        final handler = ExternalEventHandler(harness.runtimeContext);
        for (final (action, expected) in [
          ('agree', MealSuggestionResponseEvent.agree(mealId: 72)),
          ('skip', MealSuggestionResponseEvent.skip(mealId: 72)),
          (
            'snooze',
            MealSuggestionResponseEvent.snooze(mealId: 72, input: '8'),
          ),
          ('empty', MealSuggestionResponseEvent.empty(mealId: 72)),
        ]) {
          handler.handle(
            notificationResponseWire(
              notification,
              action,
              input: action == 'snooze' ? '8' : null,
            ),
          );
          expect(await inbox.nextBatch(), [expected]);
        }
        inbox.close();
      } finally {
        await tester.runAsync(harness.close);
      }
    },
  );

  testWidgets(
    'serialized AAPS carbs request actions route acknowledgement and handoff',
    (tester) async {
      final router = ForegroundToUiTestRouter();
      late ForegroundUiHarness harness;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          meals: false,
          activities: false,
          foregroundOverrides: [
            taskEventRouterProvider.overrideWithValue(router),
          ],
        );
      });
      try {
        final inbox = harness.runtimeContext
            .openEventInbox<AapsCarbsRequestAcknowledgedEvent>();
        final notification = const AapsCarbsRequestNotificationEvent(
          episodeId: 'episode-203',
          carbs: 18,
        );
        final handler = ExternalEventHandler(harness.runtimeContext);

        handler.handle(notificationResponseWire(notification, 'agree'));
        final acknowledgements = await inbox.nextBatch();
        expect(acknowledgements, hasLength(1));
        expect(acknowledgements.single.episodeId, 'episode-203');
        expect(acknowledgements.single.suggestionAt, isNull);

        handler.handle(notificationResponseWire(notification, 'empty'));
        expect(router.messages, [
          {'event': 'task_open_low_treatment', 'data': <String, dynamic>{}},
        ]);
        expect(inbox.drain(), isEmpty);
        inbox.close();
      } finally {
        await tester.runAsync(harness.close);
      }
    },
  );

  testWidgets(
    'dormant activity-finished response type routes all actions without changing activity data',
    (tester) async {
      late ForegroundUiHarness harness;
      late int activityId;
      late int activityLogId;
      await tester.runAsync(() async {
        harness = await ForegroundUiHarness.create(
          meals: false,
          activities: false,
        );
        activityId = await harness.uiDb
            .into(harness.uiDb.activity)
            .insert(
              ActivityCompanion.insert(
                name: 'Finished session',
                percentagePre: 0,
                percentagePost: 0,
              ),
            );
        final startedAt = DateTime(2026, 11, 3, 10).millisecondsSinceEpoch;
        final endedAt = DateTime(2026, 11, 3, 11).millisecondsSinceEpoch;
        activityLogId = await harness.uiDb
            .into(harness.uiDb.activityLog)
            .insert(
              ActivityLogCompanion.insert(
                activityId: activityId,
                startedAt: startedAt,
                endedAt: Value(endedAt),
              ),
            );
      });
      try {
        final startedAt = DateTime(2026, 11, 3, 10).millisecondsSinceEpoch;
        final endedAt = DateTime(2026, 11, 3, 11).millisecondsSinceEpoch;
        final inbox = harness.runtimeContext
            .openEventInbox<ActivityFinishedResponseEvent>();
        final notification = ActivityFinishedNotificationEvent(
          activityLogId: activityLogId,
          activityName: 'Finished session',
        );

        final handler = ExternalEventHandler(harness.runtimeContext);
        for (final (action, expected) in [
          (
            'agree',
            ActivityFinishedResponseEvent.agree(activityLogId: activityLogId),
          ),
          (
            'dismiss',
            ActivityFinishedResponseEvent.dismiss(activityLogId: activityLogId),
          ),
          (
            'empty',
            ActivityFinishedResponseEvent.empty(activityLogId: activityLogId),
          ),
        ]) {
          handler.handle(notificationResponseWire(notification, action));
          expect(await inbox.nextBatch(), [expected]);
        }
        final storedLog = (await tester.runAsync(
          () => harness.uiDb.activityDao.getActivityLogById(activityLogId),
        ))!;
        expect(storedLog.startedAt, startedAt);
        expect(storedLog.endedAt, endedAt);
        inbox.close();
      } finally {
        await tester.runAsync(harness.close);
      }
    },
  );
}
