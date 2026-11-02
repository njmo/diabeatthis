import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show DatabaseImpl, MealData;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/new_meal_check_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/meal_summary/domain/use_cases/complete_meal_use_case_test.dart'
    show completionDraft, seedCompletionMeal;
import '../utils/fake_runtime_harness.dart';
import '../utils/pending_notifications_controller.dart';

void main() {
  test(
    'a second shared database client finalizes confirmed intake and updates the first client stream',
    () async {
      final server = DriftIsolate.inCurrent(() => NativeDatabase.memory());
      final uiDb = DatabaseImpl(await server.connect());
      final foregroundDb = DatabaseImpl(await server.connect());
      final notifications = PendingNotificationsController();
      final ui = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(uiDb),
          notificationsControllerUiProvider.overrideWithValue(notifications),
        ],
      );
      final foreground = FakeRuntimeHarness(
        container: ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(foregroundDb),
            notificationsControllerForegroundProvider.overrideWithValue(
              notifications,
            ),
          ],
        ),
      );
      StreamSubscription<MealData>? subscription;
      addTearDown(() async {
        await subscription?.cancel();
        await foreground.dispose();
        ui.dispose();
        await foregroundDb.close();
        await uiDb.close();
        await server.shutdownAll();
      });

      expect(uiDb.hasOpened, isFalse);
      expect(foregroundDb.hasOpened, isFalse);
      await seedCompletionMeal(uiDb);
      expect(uiDb.hasOpened, isTrue);
      // Joining an already-open server alone must not count as local use.
      expect(foregroundDb.hasOpened, isFalse);
      final start = DateTime(2026, 11, 2, 12);
      final endedAt = start.add(const Duration(minutes: 15, milliseconds: 123));
      await uiDb.mealDao.updateMealStatus(
        1,
        'eating-then-bolus',
        occurredAt: start,
      );
      final completed = await withClock(
        Clock.fixed(start.add(const Duration(minutes: 20))),
        () => ui
            .read(completeMealUseCaseProvider)
            .call(
              draft: completionDraft(status: 'eating-then-bolus', consumed: 50),
              choice: MealCompletionChoice.less,
              endedAt: endedAt,
            ),
      );
      expect(completed.requiresBolus, isTrue);

      final waitingSeen = Completer<void>();
      final summarizedSeen = Completer<void>();
      subscription = (uiDb.select(uiDb.meal)..where((row) => row.id.equals(1)))
          .watchSingle()
          .listen((meal) {
            if (meal.status == 'waiting-for-bolus' &&
                !waitingSeen.isCompleted) {
              waitingSeen.complete();
            }
            if (meal.status == 'summarized' && !summarizedSeen.isCompleted) {
              summarizedSeen.complete();
            }
          });
      await waitingSeen.future.timeout(const Duration(seconds: 5));

      // This client does not receive the server's already-completed beforeOpen.
      // A real DAO query must still mark its own connection as available.
      expect(
        (await foregroundDb.mealDao.getMealById(1))!.status,
        'waiting-for-bolus',
      );
      expect(foregroundDb.hasOpened, isTrue);
      await foregroundDb.mealDao.updateMealStatus(1, 'eaten-bolused');
      foreground.container.read(databaseProvider);
      final monitor = MealMonitorContext(
        activeMeal: const Meal(id: 1, name: 'Lunch', status: 'eaten-bolused'),
      );
      final next = await FinalizeMealExecutor().execute(
        foreground.runtimeContext,
        monitor,
      );

      expect(next, isA<NewMealCheckExecutor>());
      expect(monitor.activeMeal, isNull);
      expect((await foregroundDb.mealDao.getMealById(1))!.status, 'summarized');
      expect(notifications.scheduledEvents, isEmpty);
      await summarizedSeen.future.timeout(const Duration(seconds: 5));
      final history = await uiDb.select(uiDb.mealStatusHistory).get();
      expect(
        history
            .singleWhere((row) => row.status == 'waiting-for-bolus')
            .createdAt,
        endedAt.millisecondsSinceEpoch,
      );
    },
  );
}
