import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/mappers/meal_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/record_meal_add_on_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/utils/meal_completion_amounts.dart';
import 'package:diabeatthis/foreground/providers/latest_bolus_wizard_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/meal_add_on_bolus_waiter.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/meal_summary/domain/use_cases/record_meal_add_on_use_case_test.dart'
    show addOnDraft, seedAddOnMeal;
import '../../helpers/delivered_meal_bolus.dart';
import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';
import 'meal_monitor_test.dart' show testBolusWizard;

void main() {
  final start = DateTime(2026, 11, 2, 12);
  final requestAt = start.add(const Duration(minutes: 10));
  late DatabaseImpl db;
  late ProviderContainer container;
  late FakeNotificationsController notifications;
  late FakeRuntimeHarness harness;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    notifications = FakeNotificationsController();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        notificationsControllerForegroundProvider.overrideWithValue(
          notifications,
        ),
        extendedCarbsScheduleSettingsProvider.overrideWith(
          (ref) async => const ExtendedCarbsScheduleSettings.defaults(),
        ),
      ],
    );
    harness = FakeRuntimeHarness(container: container);
    await seedAddOnMeal(db, start);
  });
  tearDown(() async {
    harness.cancel();
    container.dispose();
    await db.close();
  });

  Future<MealMonitorContext> monitorContext() async => MealMonitorContext(
    activeMeal: (await db.mealDao.getMealById(1))!.toDomain(),
  );

  Future<void> add() async {
    final draft = await addOnDraft(db, meat: 200);
    await withClock(
      Clock.fixed(requestAt),
      () => container.read(recordMealAddOnUseCaseProvider).call(draft),
    );
  }

  test(
    'cold monitor recovers a persisted calculator response and does not ask the initial bolus twice',
    () async {
      await add();
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('cold-response','aaps',?,44)",
        [requestAt.add(const Duration(minutes: 1)).millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(
        db,
        requestAt.add(const Duration(minutes: 1)),
      );
      container
          .read(latestBolusWizardProvider.notifier)
          .update(
            testBolusWizard(
              createdAt: requestAt.add(const Duration(minutes: 2)),
              carbs: 0,
            ),
          );
      final completed = await withClock(
        Clock.fixed(requestAt.add(const Duration(minutes: 2))),
        () async => const MealAddOnBolusWaiter()(
          harness.runtimeContext,
          await monitorContext(),
          remindImmediately: false,
        ),
      );
      expect(completed, isTrue);
      expect((await readMealAddOnBolusContext(db, 1))!.coveredCarbs, 44);
      expect(
        (await db.mealWizardLinkDao.forMeal(1)).single.relationType,
        'initial',
      );
      expect(
        notifications.shownEvents.whereType<MealSuggestionNotificationEvent>(),
        isEmpty,
      );
      expect(notifications.shownEvents, isEmpty);
      expect((await db.mealDao.getMealById(1))!.status, 'eating-extra');
    },
  );

  test(
    'expired eat-first add-on reminds about unpaid carbs and defers eCarbs until finishing',
    () async {
      await add();
      await withClock(
        Clock.fixed(requestAt.add(const Duration(minutes: 11))),
        () async {
          final pending = const MealAddOnBolusWaiter()(
            harness.runtimeContext,
            await monitorContext(),
            remindImmediately: false,
          );
          await pumpEventQueue(times: 100);
          final event =
              notifications.shownEvents.single
                  as MealSuggestionNotificationEvent;
          expect(event.carbs, 44);
          expect(event.extendedCarbs, 0);
          expect(event.extendedCarbsAreAdditional, isTrue);
          expect(event.body, isNot(contains('eCarbs')));
          final cancelled = expectLater(
            pending,
            throwsA(isA<TaskCancelledException>()),
          );
          harness.cancel();
          await cancelled;
        },
      );
    },
  );

  test(
    'confirmed add-on context resumes eating after restart without waiting for another calculator',
    () async {
      await add();
      await acceptDeliveredMealAddOnBolus(
        db,
        1,
        testBolusWizard(
          createdAt: requestAt.add(const Duration(seconds: 20)),
          carbs: 44,
        ),
        requestedAt: requestAt,
      );
      expect(
        await const MealAddOnBolusWaiter()(
          harness.runtimeContext,
          await monitorContext(),
          remindImmediately: false,
        ),
        isTrue,
      );
      expect(harness.activeWaitersCount, 0);
      expect(notifications.shownEvents, isEmpty);
    },
  );

  test(
    'a partial actual calculator replaces the obsolete AAPS instruction with remaining carbs',
    () async {
      await add();
      const initialInstruction = AapsBolusSuggestionNotificationEvent(
        mealId: 1,
        carbs: 44,
      );
      await notifications.show(initialInstruction);
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('partial','aaps',?,20)",
        [requestAt.add(const Duration(minutes: 1)).millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(
        db,
        requestAt.add(const Duration(minutes: 1)),
      );
      await withClock(
        Clock.fixed(requestAt.add(const Duration(minutes: 11))),
        () async {
          final pending = const MealAddOnBolusWaiter()(
            harness.runtimeContext,
            await monitorContext(),
            remindImmediately: false,
          );
          await pumpEventQueue(times: 100);
          expect(
            notifications.cancelledIds,
            contains(
              const HashNotificationIdFactory().create(initialInstruction.key),
            ),
          );
          final updated = notifications.shownEvents
              .whereType<AapsBolusSuggestionNotificationEvent>()
              .last;
          expect(updated.carbs, 24);
          expect(updated.extendedCarbs, 0);
          expect(updated.extendedCarbsAreAdditional, isTrue);
          expect(
            (notifications.shownEvents
                    .whereType<MealSuggestionNotificationEvent>())
                .single
                .carbs,
            24,
          );
          final cancelled = expectLater(
            pending,
            throwsA(isA<TaskCancelledException>()),
          );
          harness.cancel();
          await cancelled;
        },
      );
    },
  );

  test(
    'finishing a pending add-on preserves the original flow and auto summarizes after only its remaining carbs',
    () async {
      await db.mealDao.updateMealStatus(1, 'planned');
      await db.mealDao.updateMealStatus(1, 'waited-eating', occurredAt: start);
      await add();
      final end = requestAt.add(const Duration(minutes: 2));
      final draft = await addOnDraft(db);
      await withClock(
        Clock.fixed(end),
        () => container
            .read(completeMealUseCaseProvider)
            .call(
              draft: draft,
              choice: inferMealCompletionChoice(draft),
              endedAt: end,
            ),
      );
      await db.customStatement(
        "INSERT INTO bolus_wizard (local_id,source,created_at,carbs) VALUES ('pending-response','aaps',?,2)",
        [end.add(const Duration(seconds: 10)).millisecondsSinceEpoch],
      );
      await seedDeliveredMealBolus(db, end.add(const Duration(seconds: 10)));
      final context = await monitorContext();
      final next = await withClock(
        Clock.fixed(end.add(const Duration(seconds: 20))),
        () => WaitForBolusExecutor().execute(harness.runtimeContext, context),
      );
      expect(next, isA<FinalizeMealExecutor>());
      expect((await db.mealDao.getMealById(1))!.status, 'eaten-bolused');
      await next.execute(harness.runtimeContext, context);
      expect((await db.mealDao.getMealById(1))!.status, 'summarized');
      expect(notifications.scheduledEvents, isEmpty);
      expect(
        (await db.mealWizardLinkDao.forMeal(1)).single.relationType,
        'continuation',
      );
    },
  );
}
