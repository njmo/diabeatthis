import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_summary_reminder_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_snapshot_controller.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/new_meal_check_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/drift.dart' show LazyDatabase;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/meal_summary/domain/use_cases/complete_meal_use_case_test.dart'
    show completionDraft, seedCompletionMeal;
import '../utils/fake_runtime_harness.dart';
import '../utils/pending_notifications_controller.dart';

class FailingConfirmedConsumptionSnapshot extends MealSnapshotController {
  FailingConfirmedConsumptionSnapshot({required super.ref});

  @override
  Future<void> saveConsumedSnapshot(int mealId) async =>
      throw StateError('Snapshot failed');
}

void main() {
  final start = DateTime(2026, 11, 1, 14, 52);
  final end = start.add(const Duration(minutes: 15, milliseconds: 123));
  final confirmedAt = start.add(const Duration(hours: 5));
  late DatabaseImpl db;
  late ProviderContainer container;
  late PendingNotificationsController notifications;
  late FakeRuntimeHarness harness;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    notifications = PendingNotificationsController();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        notificationsControllerForegroundProvider.overrideWithValue(
          notifications,
        ),
      ],
    );
    harness = FakeRuntimeHarness(container: container);
    await seedCompletionMeal(db);
    await db.mealDao.updateMealStatus(
      1,
      'eating-then-bolus',
      occurredAt: start,
    );
  });
  tearDown(() async {
    await harness.dispose();
    await db.close();
  });

  Future<void> confirm({double consumed = 50}) =>
      withClock(Clock.fixed(confirmedAt), () async {
        await container
            .read(completeMealUseCaseProvider)
            .call(
              draft: completionDraft(
                status: 'eating-then-bolus',
                consumed: consumed,
              ),
              choice: consumed == 100
                  ? MealCompletionChoice.all
                  : MealCompletionChoice.less,
              endedAt: end,
            );
      });

  Future<void> recordBolus() => db.mealDao.updateMealStatus(
    1,
    'eaten-bolused',
    occurredAt: confirmedAt.add(const Duration(minutes: 1)),
  );

  Future<void> finalize() async {
    final context = MealMonitorContext(
      activeMeal: const Meal(id: 1, name: 'Lunch', status: 'eaten-bolused'),
    );
    final next = await FinalizeMealExecutor().execute(
      harness.runtimeContext,
      context,
    );
    expect(next, isA<NewMealCheckExecutor>());
    expect(context.activeMeal, isNull);
  }

  for (final consumed in [50.0, 100.0]) {
    test(
      'confirmed $consumed g eat-first automatically summarizes only after bolus',
      () async {
        await confirm(consumed: consumed);
        var meal = (await db.mealDao.getMealById(1))!;
        expect(meal.status, 'waiting-for-bolus');
        expect(meal.consumptionConfirmedEndedAt, end.millisecondsSinceEpoch);
        expect(
          (await db.select(db.mealSnapshot).get()).single.totalGrams,
          consumed,
        );
        expect(await db.mealDao.summarizeConfirmedMealAfterBolus(1), isFalse);
        final foreign = EatNowNotificationEvent(mealId: 2, minutes: 10);
        await notifications.show(foreign);
        await recordBolus();
        await finalize();
        meal = (await db.mealDao.getMealById(1))!;
        expect(meal.status, 'summarized');
        expect(meal.consumptionConfirmedEndedAt, isNull);
        expect(notifications.scheduledEvents, isEmpty);
        expect(notifications.contains(foreign), isTrue);
        expect(notifications.cancelAllCalled, isFalse);
        final history = await db.select(db.mealStatusHistory).get();
        expect(
          history
              .singleWhere((row) => row.status == 'waiting-for-bolus')
              .createdAt,
          end.millisecondsSinceEpoch,
        );
        expect(
          history.singleWhere((row) => row.status == 'eaten-bolused').createdAt,
          confirmedAt.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
        );
      },
    );
  }

  test(
    'snapshot without a confirmation marker retains the legacy summary reminder',
    () async {
      await confirm();
      await db.customUpdate(
        'UPDATE meal SET consumption_confirmed_ended_at = NULL WHERE id = 1',
      );
      await recordBolus();
      await finalize();
      expect((await db.mealDao.getMealById(1))!.status, 'eaten-bolused');
      expect(
        notifications.scheduledEvents.single.event,
        isA<MealSummaryReminderNotificationEvent>(),
      );
    },
  );

  test(
    'a new waiting timestamp cannot reuse another confirmed eating end',
    () async {
      await confirm();
      await db.mealDao.updateMealStatus(
        1,
        'waiting-for-bolus',
        occurredAt: end.add(const Duration(minutes: 1)),
      );
      await recordBolus();
      await finalize();
      expect((await db.mealDao.getMealById(1))!.status, 'eaten-bolused');
      expect(notifications.scheduledEvents, hasLength(1));
    },
  );

  test(
    'an add-on clears confirmation and cannot reuse an old consumed snapshot',
    () async {
      await confirm();
      await db.mealDao.updateMealStatus(
        1,
        'eating-extra',
        occurredAt: confirmedAt,
      );
      expect(
        (await db.mealDao.getMealById(1))!.consumptionConfirmedEndedAt,
        isNull,
      );
      await db.mealDao.updateMealStatus(
        1,
        'waiting-for-bolus',
        occurredAt: confirmedAt.add(const Duration(minutes: 10)),
      );
      await recordBolus();
      await finalize();
      expect((await db.select(db.mealSnapshot).get()), hasLength(1));
      expect((await db.mealDao.getMealById(1))!.status, 'eaten-bolused');
      expect(notifications.scheduledEvents, hasLength(1));
    },
  );

  test(
    'interruption clears confirmation without finalizing or scheduling a summary',
    () async {
      await confirm();
      await db.mealDao.interruptMeal(1);
      expect(
        (await db.mealDao.getMealById(1))!.consumptionConfirmedEndedAt,
        isNull,
      );
      await finalize();
      expect((await db.mealDao.getMealById(1))!.status, 'interrupted');
      expect(notifications.scheduledEvents, isEmpty);
      expect((await db.select(db.mealSnapshot).get()).single.totalGrams, 50);
    },
  );

  test(
    'missing snapshot prevents automatic summary despite a marker',
    () async {
      await confirm();
      await db.delete(db.mealSnapshot).go();
      await recordBolus();
      await finalize();
      expect((await db.mealDao.getMealById(1))!.status, 'eaten-bolused');
      expect(notifications.scheduledEvents, hasLength(1));
    },
  );

  test(
    'amount changes after confirmation require a fresh summary even without a status change',
    () async {
      await confirm();
      await db.mealIngredientsDao.updateMealIngredientConsumed(1, 75, 0.6);
      expect(
        (await db.mealDao.getMealById(1))!.consumptionConfirmedEndedAt,
        end.millisecondsSinceEpoch,
      );
      await recordBolus();
      await finalize();
      expect((await db.mealDao.getMealById(1))!.status, 'eaten-bolused');
      expect((await db.select(db.mealSnapshot).get()).single.totalGrams, 50);
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        75,
      );
      expect(notifications.scheduledEvents, hasLength(1));
    },
  );

  test(
    'snapshot failure rolls back quantities, waiting status and confirmation together',
    () async {
      final failureContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationsControllerUiProvider.overrideWithValue(notifications),
          mealSnapshotControllerProvider.overrideWith(
            (ref) => FailingConfirmedConsumptionSnapshot(ref: ref),
          ),
        ],
      );
      addTearDown(failureContainer.dispose);
      await withClock(Clock.fixed(confirmedAt), () async {
        await expectLater(
          failureContainer
              .read(completeMealUseCaseProvider)
              .call(
                draft: completionDraft(status: 'eating-then-bolus'),
                choice: MealCompletionChoice.less,
                endedAt: end,
              ),
          throwsStateError,
        );
      });
      final meal = (await db.mealDao.getMealById(1))!;
      expect(meal.status, 'eating-then-bolus');
      expect(meal.consumptionConfirmedEndedAt, isNull);
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        isNull,
      );
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
    },
  );

  test(
    'legacy in-memory finalization never opens a database or changes its reminder',
    () async {
      final legacy = FakeRuntimeHarness(
        container: ProviderContainer(
          overrides: [
            notificationsControllerForegroundProvider.overrideWithValue(
              notifications,
            ),
          ],
        ),
      );
      addTearDown(legacy.dispose);
      expect(legacy.container.exists(databaseProvider), isFalse);
      await FinalizeMealExecutor().execute(
        legacy.runtimeContext,
        MealMonitorContext(
          activeMeal: const Meal(
            id: 99,
            name: 'Legacy',
            status: 'eaten-bolused',
          ),
        ),
      );
      expect(legacy.container.exists(databaseProvider), isFalse);
      expect(
        notifications.scheduledEvents.single.event,
        isA<MealSummaryReminderNotificationEvent>(),
      );
    },
  );

  test(
    'a constructed but unopened lazy database is not a persisted confirmation',
    () async {
      var opens = 0;
      final lazyDb = DatabaseImpl(
        LazyDatabase(() async {
          opens++;
          return NativeDatabase.memory();
        }),
      );
      final legacy = FakeRuntimeHarness(
        container: ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(lazyDb),
            notificationsControllerForegroundProvider.overrideWithValue(
              notifications,
            ),
          ],
        ),
      );
      addTearDown(() async {
        await legacy.dispose();
        await lazyDb.close();
      });
      legacy.container.read(databaseProvider);
      expect(legacy.container.exists(databaseProvider), isTrue);
      expect(lazyDb.hasOpened, isFalse);
      await FinalizeMealExecutor().execute(
        legacy.runtimeContext,
        MealMonitorContext(
          activeMeal: const Meal(
            id: 99,
            name: 'Legacy',
            status: 'eaten-bolused',
          ),
        ),
      );
      expect(opens, 0);
      expect(
        notifications.scheduledEvents.single.event,
        isA<MealSummaryReminderNotificationEvent>(),
      );
    },
  );
}
