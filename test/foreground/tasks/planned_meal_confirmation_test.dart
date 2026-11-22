import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/meal_suggestion_response_event.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/mappers/meal_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/planned_meal_confirmation_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/planned_meal_confirmation.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

Future<void> settleUntil(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final action in ['yes', 'reschedule', 'cancel', 'timeout']) {
    test('$action is bound to the scheduled meal and asks at T−20', () async {
      var now = DateTime(2026, 11, 22, 8, 50);
      final plannedAt = now.add(const Duration(minutes: 25));
      final time = plannedAt.millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meal (id,name,status,purpose,planned_at) VALUES (1,'Breakfast','planned','meal',?)",
        [time],
      );
      final meal = (await db.mealDao.getMealById(1))!.toDomain();
      final notifications = FakeNotificationsController();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWith((_) async => prefs),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      addTearDown(container.dispose);
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(harness.dispose);
      final context = MealMonitorContext(activeMeal: meal);

      await withClock(Clock(() => now), () async {
        final pending = confirmPlannedMeal(
          harness.runtimeContext,
          context,
          meal,
        );
        pending.ignore();
        final due = plannedAt.subtract(const Duration(minutes: 20));
        await settleUntil(() => harness.pendingDeadlines.contains(due));
        expect(notifications.shownEvents, isEmpty);
        now = due;
        harness.dispatchTick(now);
        await settleUntil(() => notifications.shownEvents.isNotEmpty);
        final prompt =
            notifications.shownEvents.single
                as PlannedMealConfirmationNotification;
        expect(prompt.plannedAtMs, time);

        harness.dispatchEvent(
          MealSuggestionResponseEvent.agree(mealId: 1, plannedAtMs: time - 1),
        );
        switch (action) {
          case 'yes':
            harness.dispatchEvent(
              MealSuggestionResponseEvent.agree(mealId: 1, plannedAtMs: time),
            );
          case 'reschedule':
            harness.dispatchEvent(
              MealSuggestionResponseEvent.snooze(
                mealId: 1,
                plannedAtMs: time,
                input: '30',
              ),
            );
          case 'cancel':
            harness.dispatchEvent(
              MealSuggestionResponseEvent.skip(mealId: 1, plannedAtMs: time),
            );
          case 'timeout':
            now = plannedAt;
            harness.dispatchTick(now);
        }
        expect(await pending, action == 'yes');
        final stored = await db.mealDao.getMealById(1);
        expect(stored?.status, 'planned');
        expect(
          stored?.plannedAt,
          action == 'reschedule'
              ? plannedAt
                    .add(const Duration(minutes: 30))
                    .millisecondsSinceEpoch
              : time,
        );
        if (action == 'yes' || action == 'cancel') {
          expect(
            await confirmPlannedMeal(harness.runtimeContext, context, meal),
            action == 'yes',
          );
          expect(notifications.shownEvents, hasLength(1));
        }
      });
    });
  }
}
