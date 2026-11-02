import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import 'complete_meal_use_case_test.dart'
    show completionDraft, seedCompletionMeal;

void main() {
  final start = DateTime(2026, 11, 1, 14);
  final firstEnd = start.add(const Duration(minutes: 15));
  final now = start.add(const Duration(hours: 1));
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerUiProvider.overrideWithValue(
          FakeNotificationsController(),
        ),
      ],
    );
    await seedCompletionMeal(db);
    await db.mealDao.updateMealStatus(1, 'bolused-eating', occurredAt: start);
    await db.mealDao.updateMealStatus(1, 'eaten', occurredAt: firstEnd);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> blockWithAnotherMeal() => db.customInsert(
    "INSERT INTO meal (id,name,planned_at,status) VALUES (2,'Dinner',1793520000000,'eating')",
  );

  test(
    'refill rechecks another active meal inside the save transaction',
    () async {
      await blockWithAnotherMeal();
      await withClock(Clock.fixed(now), () async {
        await expectLater(
          container
              .read(completeMealUseCaseProvider)
              .completeRefill(
                draft: completionDraft(status: 'eaten', consumed: 75),
                choice: MealCompletionChoice.less,
                endedAt: now,
              ),
          throwsA(isA<MealSummaryCannotFinishException>()),
        );
      });
      expect((await db.mealDao.getMealById(1))!.status, 'eaten');
      expect((await db.mealDao.getMealById(2))!.status, 'eating');
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        isNull,
      );
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
      final history = await db.select(db.mealStatusHistory).get();
      expect(
        history.singleWhere((row) => row.status == 'eaten').createdAt,
        firstEnd.millisecondsSinceEpoch,
      );
    },
  );

  test(
    'actual deficit can still be saved while another meal is active',
    () async {
      await blockWithAnotherMeal();
      await withClock(
        Clock.fixed(now),
        () => container
            .read(completeMealUseCaseProvider)
            .call(
              draft: completionDraft(status: 'eaten'),
              choice: MealCompletionChoice.less,
              endedAt: firstEnd,
            ),
      );
      expect((await db.mealDao.getMealById(1))!.status, 'summarized');
      expect((await db.mealDao.getMealById(2))!.status, 'eating');
    },
  );

  test(
    'confirmed refill records its final time and preserves the earlier bolus',
    () async {
      await withClock(
        Clock.fixed(now),
        () => container
            .read(completeMealUseCaseProvider)
            .completeRefill(
              draft: completionDraft(status: 'eaten', consumed: 75),
              choice: MealCompletionChoice.less,
              endedAt: now,
            ),
      );
      final history = await db.select(db.mealStatusHistory).get();
      expect(
        history.singleWhere((row) => row.status == 'eaten').createdAt,
        now.millisecondsSinceEpoch,
      );
      expect(
        history.singleWhere((row) => row.status == 'bolused-eating').createdAt,
        start.millisecondsSinceEpoch,
      );
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        75,
      );
    },
  );
}
