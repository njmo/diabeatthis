import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';

void main() {
  final start = DateTime(2026, 11, 1, 14, 52);
  final now = DateTime(2026, 11, 1, 19, 52);
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
    await db.mealDao.updateMealStatus(1, 'eating', occurredAt: start);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<MealCompletionResult> save({
    String status = 'eating',
    double consumed = 50,
    double reported = 100,
    MealCompletionChoice choice = MealCompletionChoice.less,
    DateTime? end,
  }) => withClock(
    Clock.fixed(now),
    () => container
        .read(completeMealUseCaseProvider)
        .call(
          draft: completionDraft(
            status: status,
            consumed: consumed,
            reported: reported,
          ),
          choice: choice,
          endedAt: end ?? start.add(const Duration(minutes: 15)),
        ),
  );

  test(
    'partial meal is summarized with actual historical end and quantity',
    () async {
      final result = await save();
      final meal = await db.mealDao.getMealById(1);
      final items = await db.mealIngredientsDao.getMealIngredientsForMeal(1);
      final history = await db.select(db.mealStatusHistory).get();
      expect(meal?.status, 'summarized');
      expect(items.single.consumedAmount, 50);
      expect(items.single.consumedConfidence, 0.6);
      expect(
        history.singleWhere((row) => row.status == 'eaten').createdAt,
        start.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
      );
      expect(result.requiresBolus, isFalse);
      expect(result.consumedCarbs, 10);
      expect(notifications.cancelAllCalled, isFalse);
      expect(notifications.cancelledIds, isNotEmpty);
    },
  );

  test('snapshot refreshes previously cached ingredients and macros', () async {
    await container.read(getMealIngredientsDraftForMealProvider(1).future);
    await container.read(mealMacronutrientsConsumedSummaryProvider(1).future);
    await save();
    final snapshots = await db.select(db.mealSnapshot).get();
    expect(snapshots.single.totalGrams, 50);
    expect(snapshots.single.totalNetCarbsG, 10);
  });

  test('all means the reported portion including a previous add-on', () async {
    await db.customUpdate(
      'UPDATE meal_ingredients SET consumed_amount = 150 WHERE id = 1',
    );
    await save(consumed: 150, reported: 150, choice: MealCompletionChoice.all);
    final items = await db.mealIngredientsDao.getMealIngredientsForMeal(1);
    expect(items.single.consumedAmount, 150);
  });

  test(
    'whole portion plus another product does not require more of the original',
    () async {
      final draft = completionDraft(consumed: 100).copyWith(
        extraItems: [
          MealIngredientsDraft(
            ingredient: const IngredientDraft.existing(
              id: 1,
              name: 'Rice',
              carbsPer100g: 20,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 2,
              nutritionConfidence: 1,
              isReference: false,
            ),
            ingredientPortion: IngredientPortionDraft(
              portion: PortionSelection.empty(),
              amount: 1,
            ),
            amount: 25,
            quantityConfidence: 0.7,
            entryType: 'extra',
            consumedAmount: 25,
            consumedConfidence: 0.7,
          ),
        ],
      );
      await withClock(
        Clock.fixed(now),
        () => container
            .read(completeMealUseCaseProvider)
            .call(
              draft: draft,
              choice: MealCompletionChoice.more,
              endedAt: start.add(const Duration(minutes: 15)),
            ),
      );
      final items = await db.mealIngredientsDao.getMealIngredientsForMeal(1);
      expect(items, hasLength(2));
      expect(
        items.singleWhere((item) => item.entryType == 'extra').consumedAmount,
        25,
      );
      expect(
        items.singleWhere((item) => item.entryType != 'extra').consumedAmount,
        100,
      );
      expect((await db.select(db.mealSnapshot).get()).single.totalGrams, 125);
    },
  );

  test(
    'notification cleanup failure does not turn committed completion into a failed save',
    () async {
      notifications.enqueueCancelError(
        StateError('Temporary notification error'),
      );
      final result = await save();
      expect(result.requiresBolus, isFalse);
      expect((await db.mealDao.getMealById(1))?.status, 'summarized');
      expect((await db.select(db.mealSnapshot).get()), hasLength(1));
    },
  );

  test(
    'eat before bolus saves actual amount and remains waiting for bolus',
    () async {
      await db.mealDao.updateMealStatus(
        1,
        'eating-then-bolus',
        occurredAt: start,
      );
      final result = await save(status: 'eating-then-bolus');
      expect(result.requiresBolus, isTrue);
      expect((await db.mealDao.getMealById(1))?.status, 'waiting-for-bolus');
      expect((await db.select(db.mealSnapshot).get()).single.totalGrams, 50);
      expect(
        (await db.mealDao.getMealById(1))?.consumptionConfirmedEndedAt,
        result.endedAt.millisecondsSinceEpoch,
      );
      final history = await db.select(db.mealStatusHistory).get();
      expect(
        history
            .singleWhere((row) => row.status == 'waiting-for-bolus')
            .createdAt,
        result.endedAt.millisecondsSinceEpoch,
      );
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        50,
      );
    },
  );

  test(
    'corrects first eating end before a later bolus without changing bolus history',
    () async {
      await db.mealDao.updateMealStatus(
        1,
        'eating-then-bolus',
        occurredAt: start,
      );
      await db.mealDao.updateMealStatus(
        1,
        'waiting-for-bolus',
        occurredAt: now.subtract(const Duration(minutes: 20)),
      );
      final bolusAt = now.subtract(const Duration(minutes: 10));
      await db.mealDao.updateMealStatus(
        1,
        'eaten-bolused',
        occurredAt: bolusAt,
      );
      await save(status: 'eaten-bolused');
      final history = await db.select(db.mealStatusHistory).get();
      expect(
        history
            .singleWhere((row) => row.status == 'waiting-for-bolus')
            .createdAt,
        start.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
      );
      expect(
        history.singleWhere((row) => row.status == 'eaten-bolused').createdAt,
        bolusAt.millisecondsSinceEpoch,
      );
      expect((await db.mealDao.getMealById(1))?.status, 'summarized');
    },
  );

  test(
    'missing start with a waiting event preserves the later bolus timestamp',
    () async {
      await db.delete(db.mealStatusHistory).go();
      await db.mealDao.updateMealStatus(
        1,
        'waiting-for-bolus',
        occurredAt: now.subtract(const Duration(minutes: 20)),
      );
      final bolusAt = now.subtract(const Duration(minutes: 10));
      await db.mealDao.updateMealStatus(
        1,
        'eaten-bolused',
        occurredAt: bolusAt,
      );
      final actualEnd = start.add(const Duration(minutes: 15));
      await save(status: 'eaten-bolused', end: actualEnd);
      final history = await db.select(db.mealStatusHistory).get();
      expect(
        history
            .singleWhere((row) => row.status == 'waiting-for-bolus')
            .createdAt,
        actualEnd.millisecondsSinceEpoch,
      );
      expect(
        history.singleWhere((row) => row.status == 'eaten-bolused').createdAt,
        bolusAt.millisecondsSinceEpoch,
      );
    },
  );

  test(
    'missing eating history creates an end marker without overwriting bolus time',
    () async {
      await db.delete(db.mealStatusHistory).go();
      final bolusAt = now.subtract(const Duration(minutes: 10));
      await db.mealDao.updateMealStatus(
        1,
        'eaten-bolused',
        occurredAt: bolusAt,
      );
      final actualEnd = start.add(const Duration(minutes: 15));
      await save(status: 'eaten-bolused', end: actualEnd);
      final history = await db.select(db.mealStatusHistory).get();
      expect(
        history.singleWhere((row) => row.status == 'eaten').createdAt,
        actualEnd.millisecondsSinceEpoch,
      );
      expect(
        history.singleWhere((row) => row.status == 'eaten-bolused').createdAt,
        bolusAt.millisecondsSinceEpoch,
      );
    },
  );

  test('active add-on validates end against its own start', () async {
    await db.mealDao.updateMealStatus(
      1,
      'eaten',
      occurredAt: start.add(const Duration(minutes: 15)),
    );
    final extraStart = now.subtract(const Duration(minutes: 10));
    await db.mealDao.updateMealStatus(
      1,
      'eating-extra',
      occurredAt: extraStart,
    );
    await expectLater(
      save(status: 'eating-extra', end: start.add(const Duration(minutes: 20))),
      throwsA(isA<MealSummaryCannotFinishException>()),
    );
    await save(status: 'eating-extra', end: now);
    final history = await db.select(db.mealStatusHistory).get();
    expect(
      history.singleWhere((row) => row.status == 'eaten').createdAt,
      start.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
    );
    expect(
      history.singleWhere((row) => row.status == 'eaten-extra').createdAt,
      now.millisecondsSinceEpoch,
    );
  });

  for (final status in [
    'interrupted',
    'skipped',
    'summarized',
    'waiting-for-bolus',
  ]) {
    test('stale completion cannot revive $status', () async {
      await db.mealDao.updateMealStatus(1, status);
      await expectLater(
        save(),
        throwsA(isA<MealSummaryCannotFinishException>()),
      );
      expect((await db.mealDao.getMealById(1))?.status, status);
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        isNull,
      );
      expect(notifications.cancelledIds, isEmpty);
    });
  }

  test(
    'same-status amount changes invalidate stale completion draft',
    () async {
      await db.customUpdate(
        'UPDATE meal_ingredients SET consumed_amount = 150 WHERE id = 1',
      );
      await expectLater(
        save(),
        throwsA(isA<MealSummaryCannotFinishException>()),
      );
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        150,
      );
    },
  );

  for (final end in [
    start.subtract(const Duration(minutes: 1)),
    now.add(const Duration(minutes: 1)),
  ]) {
    test('invalid end $end writes no consumption or status', () async {
      await expectLater(
        save(end: end),
        throwsA(isA<MealSummaryCannotFinishException>()),
      );
      expect((await db.mealDao.getMealById(1))?.status, 'eating');
      expect(
        (await db.mealIngredientsDao.getMealIngredientsForMeal(
          1,
        )).single.consumedAmount,
        isNull,
      );
    });
  }

  test('zero food cannot be silently summarized as eaten', () async {
    await expectLater(
      save(consumed: 0),
      throwsA(isA<MealSummaryCannotFinishException>()),
    );
    expect((await db.mealDao.getMealById(1))?.status, 'eating');
  });
}

MealSummaryDraft completionDraft({
  String status = 'eating',
  double consumed = 50,
  double reported = 100,
}) => MealSummaryDraft(
  mealId: 1,
  mealStatus: status,
  itemIds: const [1],
  itemsById: {
    1: MealSummaryItemDraft(
      name: 'Rice',
      mealIngredientId: 1,
      plannedAmount: 100,
      reportedAmount: reported,
      amountLabel: 'g',
      netCarbsPerAmount: 0.2,
      consumedAmount: consumed,
      consumedConfidence: 0.6,
      gramsPerAmount: 1,
    ),
  },
  extraItems: const [],
);

Future<void> seedCompletionMeal(DatabaseImpl db) async {
  await db.customInsert('''INSERT INTO ingredient
    (id,name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,carbs_label_mode,nutrition_confidence)
    VALUES (1,'Rice',20,0,0,2,'eu',1)''');
  await db.customInsert(
    "INSERT INTO meal (id,name,planned_at,status) VALUES (1,'Lunch',1793520000000,'eating')",
  );
  await db.customInsert('''INSERT INTO meal_ingredients
    (id,meal_id,ingredient_id,portion_id,amount,quantity_confidence)
    VALUES (1,1,1,NULL,100,0.8)''');
}
