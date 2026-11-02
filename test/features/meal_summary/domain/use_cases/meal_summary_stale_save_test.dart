import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event_type.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_key.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import 'complete_meal_use_case_test.dart'
    show completionDraft, seedCompletionMeal;

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  late FakeNotificationsController notifications;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    notifications = FakeNotificationsController();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerUiProvider.overrideWithValue(notifications),
      ],
    );
    await seedCompletionMeal(db);
    await db.mealDao.updateMealStatus(1, 'eaten');
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> save({
    String status = 'eaten',
    MealSummarySaveMode mode = MealSummarySaveMode.finishMeal,
  }) => container
      .read(finalizeMealSummaryUseCaseProvider)
      .call(completionDraft(status: status), mode: mode);

  Future<void> addOtherActiveMeal() => db.customInsert(
    "INSERT INTO meal (id,name,planned_at,status) VALUES (2,'Other meal',1793520000000,'bolused-eating')",
  );

  for (final status in ['interrupted', 'summarized', 'waiting-for-bolus']) {
    test('stale summary cannot write quantities after $status', () async {
      await db.mealDao.updateMealStatus(1, status);
      await expectLater(
        save(),
        throwsA(isA<MealSummaryCannotFinishException>()),
      );
      expect((await db.mealDao.getMealById(1))!.status, status);
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        isNull,
      );
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
      expect(notifications.cancelledIds, isEmpty);
      expect(notifications.cancelAllCalled, isFalse);
    });
  }

  test(
    'stale quantities cannot overwrite a newer report in the same status',
    () async {
      await db.customUpdate(
        'UPDATE meal_ingredients SET consumed_amount = 75 WHERE id = 1',
      );
      await expectLater(
        save(),
        throwsA(isA<MealSummaryCannotFinishException>()),
      );
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        75,
      );
      expect((await db.mealDao.getMealById(1))!.status, 'eaten');
      expect(notifications.cancelledIds, isEmpty);
    },
  );

  test('continuing an older meal cannot bypass another active meal', () async {
    await addOtherActiveMeal();
    await expectLater(
      save(mode: MealSummarySaveMode.continueEating),
      throwsA(isA<MealSummaryCannotFinishException>()),
    );
    expect((await db.mealDao.getMealById(1))!.status, 'eaten');
    expect(
      (await db.mealIngredientsDao.getMealIngredientsForMeal(
        1,
      )).single.consumedAmount,
      isNull,
    );
    expect(notifications.cancelledIds, isEmpty);
  });

  test(
    'finishing an older meal preserves active meal and its notifications',
    () async {
      await addOtherActiveMeal();
      await container.read(getMealIngredientsDraftForMealProvider(1).future);
      await container.read(mealMacronutrientsConsumedSummaryProvider(1).future);
      await save();
      expect((await db.mealDao.getMealById(1))!.status, 'summarized');
      expect((await db.mealDao.getMealById(2))!.status, 'bolused-eating');
      expect((await db.select(db.mealSnapshot).get()).single.totalGrams, 50);
      expect(notifications.cancelAllCalled, isFalse);
      expect(notifications.cancelledIds, isNotEmpty);
      for (final type in NotificationEventType.values) {
        final key = type == NotificationEventType.tempTarget
            ? TempTargetNotificationEvent.meal(entityId: 2).key
            : NotificationKey(type: type, entityId: 2);
        expect(
          notifications.cancelledIds,
          isNot(contains(const HashNotificationIdFactory().create(key))),
        );
      }
    },
  );

  for (final status in [
    'eating-then-bolus',
    'bolused-eating',
    'waited-eating',
  ]) {
    test('continuing $status retains the bolus workflow', () async {
      await db.mealDao.updateMealStatus(1, status);
      await save(status: status, mode: MealSummarySaveMode.continueEating);
      expect((await db.mealDao.getMealById(1))!.status, status);
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        50,
      );
      expect(notifications.cancelAllCalled, isFalse);
    });
  }

  test(
    'notification failures do not invite retry of a committed summary',
    () async {
      notifications.enqueueCancelError(StateError('Temporary failure'));
      notifications.enqueueCancelError(StateError('Still unavailable'));
      await save();
      expect((await db.mealDao.getMealById(1))!.status, 'summarized');
      expect((await db.select(db.mealSnapshot).get()).single.totalGrams, 50);
    },
  );
}
