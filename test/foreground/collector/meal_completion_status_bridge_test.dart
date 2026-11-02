import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/interrupt_meal_use_case.dart';
import 'package:diabeatthis/foreground/collector/meal_status_collector.dart';
import 'package:diabeatthis/foreground/event/internal/meal_status_changed_event.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  final start = DateTime(2026, 11, 1, 14);
  final finish = start.add(const Duration(minutes: 15));
  late DatabaseImpl db;
  late ProviderContainer ui;
  late ProviderContainer foreground;
  late FakeRuntimeHarness harness;
  late MealStatusCollector collector;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    ui = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerUiProvider.overrideWithValue(
          FakeNotificationsController(),
        ),
      ],
    );
    foreground = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    harness = FakeRuntimeHarness(container: foreground);
    collector = MealStatusCollector();
    await db
        .into(db.ingredient)
        .insert(
          IngredientCompanion.insert(
            name: 'Rice',
            carbsPer100g: 20,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 2,
            nutritionConfidence: 1,
          ),
        );
    await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Lunch',
            plannedAt: start.millisecondsSinceEpoch,
          ),
        );
    await db
        .into(db.mealIngredients)
        .insert(
          MealIngredientsCompanion.insert(
            mealId: 1,
            ingredientId: 1,
            amount: const Value(100),
            quantityConfidence: 1,
          ),
        );
    collector.start(
      CollectorContext.fromRuntimeContext(harness.runtimeContext),
    );
  });

  tearDown(() async {
    await collector.dispose();
    harness.cancel();
    foreground.dispose();
    ui.dispose();
    await db.close();
  });

  for (final status in ['eating', 'eating-then-bolus']) {
    test(
      'UI completion of $status publishes only committed foreground state',
      () async {
        await db.mealDao.updateMealStatus(1, status, occurredAt: start);
        await pumpEventQueue();
        harness.emittedEvents.clear();

        final subscription = ui.listen(
          mealSummaryControllerProvider(1),
          (_, _) {},
        );
        addTearDown(subscription.close);
        await ui.read(mealSummaryControllerProvider(1).future);
        ui
            .read(mealSummaryControllerProvider(1).notifier)
            .setReportedPortionFactor(0.5);
        final draft = ui.read(mealSummaryControllerProvider(1)).requireValue;
        await withClock(
          Clock.fixed(start.add(const Duration(hours: 5))),
          () => ui
              .read(completeMealUseCaseProvider)
              .call(
                draft: draft,
                choice: MealCompletionChoice.less,
                endedAt: finish,
              ),
        );
        await pumpEventQueue();

        final events = harness.emittedEvents
            .whereType<MealStatusChangedEvent>()
            .toList();
        final expected = status == 'eating'
            ? 'summarized'
            : 'waiting-for-bolus';
        expect(events.map((event) => event.toJson()['kind']), [expected]);
        expect(events.single.mealId, 1);
        expect(
          (await foreground.read(databaseProvider).mealDao.getMealById(1))
              ?.status,
          expected,
        );
        final items = await foreground
            .read(databaseProvider)
            .mealIngredientsDao
            .getMealIngredientsForMeal(1);
        expect(items.single.consumedAmount, 50);
        final history = await db.select(db.mealStatusHistory).get();
        expect(
          history
              .singleWhere(
                (row) =>
                    row.status ==
                    (status == 'eating' ? 'eaten' : 'waiting-for-bolus'),
              )
              .createdAt,
          finish.millisecondsSinceEpoch,
        );
      },
    );
  }

  test(
    'UI interruption reaches foreground and stale writes emit no restart',
    () async {
      await db.mealDao.updateMealStatus(1, 'eating', occurredAt: start);
      await pumpEventQueue();
      harness.emittedEvents.clear();
      expect(
        await ui.read(interruptMealUseCaseProvider)(
          1,
          expectedStatus: 'eating',
        ),
        isTrue,
      );
      await pumpEventQueue();
      await db.mealDao.updateMealStatus(1, 'eaten');
      await pumpEventQueue();
      final events = harness.emittedEvents
          .whereType<MealStatusChangedEvent>()
          .toList();
      expect(events, hasLength(1));
      expect(events.single, isA<MealInterruptedEvent>());
      expect(events.single.mealId, 1);
    },
  );
}
