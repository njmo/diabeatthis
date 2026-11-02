import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import 'complete_meal_use_case_test.dart'
    show completionDraft, seedCompletionMeal;

void main() {
  test(
    'completion cleanup preserves a bolus reminder posted after its commit',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final start = DateTime(2026, 11, 2, 12);
      final end = start.add(const Duration(minutes: 20));
      await seedCompletionMeal(db);
      await db.mealDao.updateMealStatus(
        1,
        'eating-then-bolus',
        occurredAt: start,
      );
      final reminder = MealSuggestionNotificationEvent(
        mealId: 1,
        minutes: 0,
        decision: MealDecision.bolus,
        carbs: 20,
      );
      late InterleavedCompletionNotifications notifications;
      notifications = InterleavedCompletionNotifications(
        onFirstCancel: () async {
          expect(
            (await db.mealDao.getMealById(1))!.status,
            'waiting-for-bolus',
          );
          // The foreground observes the committed state before UI cleanup ends.
          await notifications.show(reminder);
        },
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationsControllerUiProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final result = await withClock(
        Clock.fixed(end),
        () => container
            .read(completeMealUseCaseProvider)
            .call(
              draft: completionDraft(
                status: 'eating-then-bolus',
                consumed: 100,
              ),
              choice: MealCompletionChoice.all,
              endedAt: end,
            ),
      );
      expect(result.requiresBolus, isTrue);
      final reminderId = const HashNotificationIdFactory().create(reminder.key);
      expect(notifications.liveIds, contains(reminderId));
      expect(notifications.cancelledIds, isNot(contains(reminderId)));
      expect(notifications.cancelAllCalled, isFalse);
    },
  );
}

class InterleavedCompletionNotifications extends FakeNotificationsController {
  InterleavedCompletionNotifications({required this.onFirstCancel});

  final Future<void> Function() onFirstCancel;
  final Set<int> liveIds = {};
  bool startedCleanup = false;

  @override
  Future<void> show(NotificationEvent event) async {
    await super.show(event);
    liveIds.add(const HashNotificationIdFactory().create(event.key));
  }

  @override
  Future<void> cancel(int id) async {
    if (!startedCleanup) {
      startedCleanup = true;
      await onFirstCancel();
    }
    await super.cancel(id);
    liveIds.remove(id);
  }
}
